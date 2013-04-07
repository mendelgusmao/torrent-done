#!env ruby

require "resque"
require "open4"
require "yaml"

class TorrentDone
    @queue = :transmission

    def self.perform(config, filename)
        Dir.chdir(File.dirname(filename))

        cmd = config["subtitles"] % filename

        err = ""
        if Open4::popen4(cmd) { |p,i,o,e| err = e.read } == 0
            Resque.enqueue(ConvertAndRename, config, filename)
        else
            raise "Couldn't download subtitle for #{filename}: \n#{err}"
        end
    end
end

class ConvertAndRename
    @queue = :transmission

    def self.perform(config, filename)
        Dir.chdir(File.dirname(filename))
        *filename, extension = filename.split(".")
        filename = filename.join(".")

        cmd = config["convert"] % [ filename, "#{filename}.#{extension}", filename ]

        err = ""
        if Open4::popen4(cmd) { |p,i,o,e| err = e.read } == 0
            rename("#{filename}.#{extension}")
        else
            raise "Couldn't convert #{filename}.#{extension}: \n#{err}"
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

    config = YAML.load_file(File.dirname(__FILE__) + "/torrent-done.yaml")
    extensions = config["extensions"].split(" ")

    Dir.chdir(directory)
    Dir.glob("**/*").each do |filename|
        if extensions.include? filename.split(".").last.downcase
            Resque.enqueue(TorrentDone, config, "#{directory}/#{filename}")
        end
    end
end