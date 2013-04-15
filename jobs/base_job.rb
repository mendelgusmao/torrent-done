class BaseJob
    @all_config = nil

    def self.read
        config_file = File.dirname(__FILE__) + "/../torrent-done.yaml"
        @all_config ||= YAML.load_file(config_file)
    end

    def self.get_job_config
        read()[self.to_s]
    end

    def self.perform(jobs, *args)
        moreargs = execute(*args)
        args << moreargs unless moreargs.nil?
        Resque.enqueue(jobs.shift.constantize, jobs, *args) unless jobs.empty?
    end
end
