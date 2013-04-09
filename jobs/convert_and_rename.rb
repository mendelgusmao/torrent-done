class ConvertAndRename < BaseJob
    @config = get_job_config()
    @queue = @config["queue"]

    def self.execute(filename)
        Dir.chdir(File.dirname(filename))
        *filename, extension = filename.split(".")
        filename = filename.join(".")

        cmd = @config["command"] % [ filename, "#{filename}.#{extension}", filename ]

        err = ""
        out = ""
        if Open4::popen4(cmd) { |p,i,o,e| err, out = e.read, o.read } == 0
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
