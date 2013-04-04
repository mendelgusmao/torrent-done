#!env ruby

require "resque"
require "open3"

class Subtitles
    SUBLIMINAL = "/usr/local/bin/subliminal"
    SUB2SRT = "/etc/scripts/sub2srt"
    @queue = :transmission

    def self.perform(file, service = "opensubtitles")
        filename = file.join(".")

        cmd = [SUBLIMINAL]
        cmd << "--force"
        cmd << "-s #{service}" unless service.empty?
        cmd << "-l pt-br"
        cmd << "'#{filename}'"

        sin, sout, serr = Open3.popen3(cmd.join(" "))

        if $? == 0
            Resque.enqueue(Convert, file)
        else
            unless service == ""
                Resque.enqueue(Subtitles, file, "")
            else
                raise "Couldn't download subtitle for #{filename}: \n#{serr.read}"
            end
        end
    end
end

class Convert
    MKVMERGE = "/usr/bin/mkvmerge"
    @queue = :transmission

    def self.perform(file)
        filename = file.join(".")

        cmd = [
            MKVMERGE,
            "-o '#{file.first}.sub.mkv'",
            "'#{filename}'",
            "--clusters-in-meta-seek",
            "--engage no_cue_duration",
            "--engage no_cue_relative_position",
            "--subtitle-charset 0:ISO-8859-1",
            "'#{file.first}.srt'"
        ]

        sin, sout, serr = Open3.popen3(cmd.join(" "))

        if $? == 0
            Resque.enqueue(Rename, file)
        else
            raise "Couldn't convert #{filename}: \n#{serr.read}"
        end
    end
end

class Rename
    @queue = :transmission

    def self.perform(file)
        unless file.last.downcase == "mkv"
            filename = file.join(".")
            File.rename(filename, "#{filename}.old") 
        end

        File.rename("#{file.first}.sub.mkv", "#{file.first}.mkv")
    end
end

class TorrentDone
    EXTENSIONS=["mkv", "mp4", "avi", "rmvb"]
    @queue = :transmission

    def self.perform(directory)
        Dir.chdir(directory)
        Dir.glob("*").each do |filename|
            *filename, extension = filename.split(".")
            file = [directory + "/" + filename.join("."), extension]

            if EXTENSIONS.include? file.last.downcase
                Resque.enqueue(Subtitles, file)
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
