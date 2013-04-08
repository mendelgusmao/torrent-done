#!env ruby

require "resque"
require "open4"
require "yaml"
require "active_support/inflector"

class Base
    def self.read
        YAML.load_file(File.dirname(__FILE__) + "/torrent-done.yaml")
    end

    def self.get_job_config
        read()[self.to_s.underscore]
    end

    def self.perform(jobs, filename)
        execute(filename)
        Resque.enqueue(jobs.shift.camelize.constantize, jobs, filename) unless jobs.empty?
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

    def self.execute(filename)
        style = @config["style"] 
        *filename, extension = filename.split(".")
        filename = filename.join(".")

        content = File.open("#{filename}.srt", "r:iso-8859-1") { |io| io.read }.to_s
 
        # http://activearchives.org/wiki/Cookbook#Convert_.srt_subtitles_into_.ssa_allowing_styling
        content.gsub!(/^[0-9]*$/, "")
        content.gsub!(/ --> /, ",")
        content.gsub!(/([0-9][0-9]),([0-9][0-9][0-9])/, '\1.\2')
        content.gsub!(/([0-9].*[0-9])/, 'Dialogue: 1,\0,MyStyle,NTP,0000,0000,0000,,')
        content.gsub!("\n", "")
        content.gsub!(/Dialogue/, "\n" + '\0')
        content.gsub!(/(,)[0-9]([0-9]:)/, '\1\2')

        File.open("#{filename}.ssa", "w:iso-8859-1") { |io| io.write("#{style}\n#{content}") }
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
        File.rename(filename, "#{filename}.old") 
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

    Dir.chdir(directory)
    Dir.glob("**/*").sort.each do |filename|
        if extensions.include? filename.split(".").last.downcase
            jobs = config["jobs"].split(" ")
            Resque.enqueue(jobs.shift.camelize.constantize, jobs, "#{directory}/#{filename}")
        end
    end
end
