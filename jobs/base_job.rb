class BaseJob
    @all_config = nil

    def self.read
        @all_config ||= YAML.load_file(File.dirname(__FILE__) + "/../torrent-done.yaml")
    end

    def self.get_job_config
        read()[self.to_s]
    end

    def self.perform(jobs, filename)
        execute(filename)
        Resque.enqueue(jobs.shift.constantize, jobs, filename) unless jobs.empty?
    end
end
