class ConvertAndRename < BaseJob
    @config = get_job_config()
    @queue = @config["queue"]

    def self.execute(filename, subtitle_format)
        *filename, extension = filename.split(".")
        filename = filename.join(".")

        options = [ 
            filename, 
            "#{filename}.#{extension}", 
            detect_encoding(filename, subtitle_format), 
            filename,
            subtitle_format 
        ]
        cmd = @config["command"] % options

        err = ""
        out = ""
        if Open4::popen4(cmd) { |p,i,o,e| err, out = e.read, o.read } == 0
            rename("#{filename}.#{extension}")
        else
            raise "Couldn't convert #{filename}.#{extension}: \n#{out}\n#{err}"
        end
        
        nil
    end

    def self.rename(filename)
        if @config["backup"].to_i == 1
            File.rename(filename, "#{filename}.old") 
        else
            File.unlink(filename)
        end

        *filename, extension = filename.split(".")
        filename = filename.join(".")
        File.rename("#{filename}.sub.mkv", "#{filename}.mkv")
    end

    def self.detect_encoding(filename, subtitle_format)
        contents = File.read("#{filename}.#{subtitle_format}")
        detection = CharlockHolmes::EncodingDetector.detect(contents)
        detection[:encoding]
    end     
end
