class TorrentDone < BaseJob
    @config = get_job_config() 
    @queue = @config["queue"]

    def self.execute(directory)
        extensions = @config["extensions"]
        selected_jobs = @all_config.select do |k, v| 
            k != self.to_s and v["disabled"].to_i != 1
        end

        Dir.chdir(directory)
        Dir.glob("**/*").sort.each do |filename|
            if extensions.include? filename.split(".").last.downcase
                jobs = selected_jobs.keys
                Resque.enqueue(jobs.shift.constantize, jobs, "#{directory}/#{filename}")
            end
        end
    end
end
