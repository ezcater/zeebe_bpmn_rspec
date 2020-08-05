# frozen_string_literal: true

# Wrapper for ActivateJob in specs. Stores the requested `type` even if a job is not activated.
module ZeebeBpmnRspec
  class ActivatedJobTarget
    attr_reader :type

    def initialize(type, job = nil)
      @type = type
      @job = job
    end

    def method_missing(symbol, *args)
      if ActivatedJob.instance_methods.include?(symbol)
        @job.public_send(symbol, *args)
      else
        super
      end
    end

    def respond_to_missing?(name, include_all = true)
      ActivatedJob.instance_methods.include?(name) || super
    end
  end
end
