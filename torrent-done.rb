#!env ruby

require "resque"
require "open4"

EXTENSIONS=["mkv", "mp4", "avi", "rmvb"]

class TorrentDone
    DEFAULT_SERVICE = "opensubtitles"
    SUBLIMINAL = "/usr/local/bin/subliminal"

    @queue = :transmission

    def self.perform(filename, service = DEFAULT_SERVICE)
        Dir.chdir(File.dirname(filename))

        cmd = [SUBLIMINAL]
        cmd << " --force"
        cmd << " -w 1"
        cmd << " -s #{service}" unless service.nil?
        cmd << " -l pt-br"
        cmd << " '#{filename}'"

        err = ""
        if Open4::popen4(cmd.join) { |p,i,o,e| err = e.read } == 0
            Resque.enqueue(ConvertAndRename, filename)
        else
            raise "Couldn't download subtitle for #{filename}: \n#{err}" if service.nil?
            perform(filename, nil)
        end
    end
end

class ConvertAndRename
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

    Dir.chdir(directory)
    Dir.glob("**/*").each do |filename|
        if EXTENSIONS.include? filename.split(".").last.downcase
            Resque.enqueue(TorrentDone, "#{directory}/#{filename}")
        end
    end
end