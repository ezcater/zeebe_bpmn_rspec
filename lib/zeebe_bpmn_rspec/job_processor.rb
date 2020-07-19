# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/hash/keys"
require "json"

module ZeebeBpmnRspec
  class JobProcessor
    include ::Zeebe::Client::GatewayProtocol # for direct reference of request classes

    attr_accessor :job, :type, :workflow_instance_key, :client, :context

    def initialize(job, type:, workflow_instance_key:, client:, context:)
      @job = job
      @type = type
      @workflow_instance_key = workflow_instance_key
      @client = client
      @context = context

      context.instance_eval do
        aggregate_failures do
          expect(job.workflowInstanceKey).to eq(workflow_instance_key)
          expect(job.type).to eq(type)
        end
      end
    end

    # alias as with_inputs()?
    def with(data, headers: nil)
      _job = job
      data = data.stringify_keys if data.is_a?(Hash)
      context.instance_eval do
        aggregate_failures do
          expect(JSON.parse(_job.variables)).to match(data)
          expect(JSON.parse(_job.customHeaders)).to match(headers.stringify_keys) if headers # TODO
        end
      end

      self
    end

    def with_headers(headers)
      job_headers = job.customHeaders
      context.instance_eval do
        expect(JSON.parse(job_headers)).to match(headers.stringify_keys) # TODO
      end

      self
    end

    def throw_error(error_code, message = nil)
      client.throw_error(ThrowErrorRequest.new(
                           {
                             jobKey: job.key,
                             errorCode: error_code,
                             errorMessage: message,
                           }.compact
                         ))

      self
    end

    def and_fail(message = nil)
      client.fail_job(FailJobRequest.new(
                        {
                          jobKey: job.key,
                          retries: 0,
                          errorMessage: message,
                        }.compact
                      ))
    end

    def and_complete(data = {})
      client.complete_job(CompleteJobRequest.new(
                            jobKey: job.key,
                            variables: data.to_json
                          ))
    end
  end
end
