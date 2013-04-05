#!env ruby

require "resque"
require "open4"

class Subtitles
    SUBLIMINAL = "/usr/local/bin/subliminal"
    DEFAULT_SERVICE = "opensubtitles"
    @queue = :transmission

    def self.perform(filename, service = DEFAULT_SERVICE)
        Dir.chdir(File.dirname(filename))

        cmd = [SUBLIMINAL]
        cmd << " --force"
        cmd << " -s #{service}" unless service.empty?
        cmd << " -l pt-br"
        cmd << " '#{filename}'"

        err = ""
        if Open4::popen4(cmd.join) { |p,i,o,e| err = e.read } == 0
            Resque.enqueue(Convert, filename)
        else
            unless service == ""
                Resque.enqueue(Subtitles, filename, "")
            else
                raise "Couldn't download subtitle for #{filename}: \n#{err}"
            end
        end
    end
end

class Convert
    MKVMERGE = "/usr/bin/mkvmerge"
    @queue = :transmission

    def self.perform(filename)
        Dir.chdir(File.dirname(filename))
        *filename, extension = filename.split(".")
        filename = filename.join(".")

        cmd = [
            MKVMERGE,
            " -o '#{filename}.sub.mkv'",
            " '#{filename}.#{extension}'",
            " --clusters-in-meta-seek",
            " --engage no_cue_duration",
            " --engage no_cue_relative_position",
            " --subtitle-charset 0:ISO-8859-1",
            " '#{filename}.srt'"
        ]

        err = ""
        if Open4::popen4(cmd.join) { |p,i,o,e| err = e.read } == 0
            Resque.enqueue(Rename, filename)
        else
            raise "Couldn't convert #{filename}.#{extension}: \n#{err}"
        end
    end
end

class Rename
    @queue = :transmission

    def self.perform(filename)
        Dir.chdir(File.dirname(filename))
        File.rename(filename, "#{filename}.old") 
        *filename, extension = filename.split(".")
        filename = filename.join(".")
        File.rename("#{filename}.sub.mkv", "#{filename}.mkv")
    end
end

class TorrentDone
    EXTENSIONS=["mkv", "mp4", "avi", "rmvb"]
    @queue = :transmission

    def self.perform(directory)
        Dir.chdir(directory)
        Dir.glob("*").each do |filename|
            if EXTENSIONS.include? filename.split(".").last.downcase
                Resque.enqueue(Subtitles, "%s/%s" % [directory, filename]) 
            end
        end
    end
end

if $PROGRAM_NAME == __FILE__
    torrent_directory = ARGV.first || [
        ENV["TR_TORRENT_DIR"],
        ENV["TR_TORRENT_NAME"]
    ].join("/")

    Resque.enqueue(TorrentDone, torrent_directory)
end
