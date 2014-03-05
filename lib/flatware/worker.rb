require 'flatware/sink/client'
module Flatware
  class Worker
    attr_reader :id

    def initialize(id, runner, dispatch_endpoint, sink_endpoint)
      @id       = id
      @runner   = runner
      @fireable = Fireable.new
      @sink     = Sink::Client.new sink_endpoint
      @task     = Flatware.socket ZMQ::REQ, connect: dispatch_endpoint
    end

    def self.spawn(worker_count, runner, dispatch_endpoint, sink_endpoint)
      worker_count.times do |i|
        fork do
          $0 = "flatware worker #{i}"
          ENV['TEST_ENV_NUMBER'] = i.to_s
          new(i, runner, dispatch_endpoint, sink_endpoint).listen
        end
      end
    end

    def listen
      Sink.client = sink
      report_for_duty
      fireable.until_fired task do |job|
        job.worker = id
        sink.started job
        runner.run job.id, job.args
        sink.finished job
        report_for_duty
      end
    end

    private

    attr_reader :fireable, :task, :sink, :runner

    def report_for_duty
      task.send 'ready'
    end
  end
end
