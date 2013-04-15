#!/usr/bin/env ruby

require_relative "torrent-done"

class SimpleJob < BaseJob
  @queue = "torrent-done-test"

  def self.execute(who)
    Resque.logger.info "TEST This is a simple job for #{who}"
    nil
  end
end

class JobAddingMoreParameters < BaseJob
  @queue = "torrent-done-test"

  def self.execute(who)
    who2 = "Maria"
    Resque.logger.info "TEST Now #{who} is going to make #{who2} have some work too"
    who2
  end
end

class JobReceivingMoreParameters < BaseJob
  @queue = "torrent-done-test"

  def self.execute(who, who2)
    Resque.logger.info "TEST This is a job that #{who2} received from #{who}"
  end
end

if $PROGRAM_NAME == __FILE__
  Resque.enqueue(SimpleJob, [JobAddingMoreParameters, JobReceivingMoreParameters], "John")
end
