#!env ruby

require "resque"
require "open4"
require "yaml"
require "active_support/inflector"
require "srt"

class Base
    def self.read
        YAML.load_file(File.dirname(__FILE__) + "/torrent-done.yaml")
    end

    def self.get_job_config
        read()["jobs"][self.to_s]
    end

    def self.perform(jobs, filename)
        execute(filename)
        Resque.enqueue(jobs.shift.constantize, jobs, filename) unless jobs.empty?
    end
end

class DownloadSubtitles < Base
    @config = get_job_config() 
    @queue = @config["queue"]

    def self.execute(filename)
        Dir.chdir(File.dirname(filename))

        cmd = @config["command"] % filename

        err = ""
        out = ""
        if Open4::popen4(cmd) { |p,i,o,e| err = e.read; out = o.read } != 0
            raise "Couldn't download subtitle for #{filename}: \n#{out}\n#{err}"
        end
    end
end

class ConvertSubtitles < Base
    @config = get_job_config() 
    @queue = @config["queue"]
    DIALOGUE = "Dialogue: Marked=0,%s,%s,Default,,0000,0000,0000,,%s"

    def self.execute(filename)
        style = @config["style"] 
        *filename, extension = filename.split(".")
        filename = filename.join(".")

        srt = SRT::File.parse(File.new("#{filename}.srt", "r:iso-8859-1"))
        ssa = []

        srt.lines.each do |line|
            line = format_time(line.start_time), format_time(line.end_time), line.text.join("\\N")
            ssa << DIALOGUE % line
        end

        ssa = ssa.join("\n")

        File.open("#{filename}.ssa", "w:iso-8859-1") { |io| io.write("#{style}#{ssa}") }
    end

    def self.format_time(t)
        t = t.round(2)
        time = t / 3600, (t % 3600) / 60, t % 60, (t.abs.modulo(1) * 100).to_i
        sprintf("%01d:%02d:%02d.%02d", *time)
    end
end

class ConvertAndRename < Base
    @config = get_job_config()
    @queue = @config["queue"]

    def self.execute(filename)
        Dir.chdir(File.dirname(filename))
        *filename, extension = filename.split(".")
        filename = filename.join(".")

        cmd = @config["command"] % [ filename, "#{filename}.#{extension}", filename ]

        err = ""
        out = ""
        if Open4::popen4(cmd) { |p,i,o,e| err = e.read; out = o.read } == 0
            rename("#{filename}.#{extension}")
        else
            raise "Couldn't convert #{filename}.#{extension}: \n#{out}\n#{err}"
        end
    end

    def self.rename(filename)
        Dir.chdir(File.dirname(filename))

        if @config["backup"].to_i == 1
            File.rename(filename, "#{filename}.old") 
        else
            File.unlink(filename)
        end

        *filename, extension = filename.split(".")
        filename = filename.join(".")
        File.rename("#{filename}.sub.mkv", "#{filename}.mkv")
    end
end

if $PROGRAM_NAME == __FILE__
    directory = ARGV.first || [
        ENV["TR_TORRENT_DIR"],
        ENV["TR_TORRENT_NAME"]
    ].join("/")

    config = Base.read()
    extensions = config["extensions"].split(" ")
    selected_jobs = config["jobs"].select { |k, v| v["disabled"].to_i != 1 }

    Dir.chdir(directory)
    Dir.glob("**/*").sort.each do |filename|
        if extensions.include? filename.split(".").last.downcase
            jobs = selected_jobs.keys
            Resque.enqueue(jobs.shift.constantize, jobs, "#{directory}/#{filename}")
        end
    end
end
