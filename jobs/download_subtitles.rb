class DownloadSubtitles < BaseJob
    @config = get_job_config() 
    @queue = @config["queue"]

    def self.execute(filename)
        Dir.chdir(File.dirname(filename))

        cmd = @config["command"] % filename

        err = ""
        out = ""
        if Open4::popen4(cmd) { |p,i,o,e| err, out = e.read, o.read } != 0
            raise "Couldn't download subtitle for #{filename}: \n#{out}\n#{err}"
        end

        fix_encoding(filename)
    end

    def self.fix_encoding(filename)
        *filename, extension = filename.split(".")
        filename = filename.join(".")

        srt_contents = File.read("#{filename}.srt")
        detection = CharlockHolmes::EncodingDetector.detect(srt_contents)
        srt_contents = CharlockHolmes::Converter.convert(srt_contents, detection[:encoding], 'UTF-8')

        File.open("#{filename}.srt", "w:utf-8") do |io|
            io.write(srt_contents)
        end
    end
end
