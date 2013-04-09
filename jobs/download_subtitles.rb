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
    end
end
