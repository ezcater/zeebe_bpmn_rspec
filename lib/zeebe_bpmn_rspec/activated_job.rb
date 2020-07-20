# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/hash/keys"
require "json"

module ZeebeBpmnRspec
  class ActivatedJob
    include ::Zeebe::Client::GatewayProtocol # for direct reference of request classes

    attr_reader :job, :type, :workflow_instance_key

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

    def key
      job.key
    end

    def variables
      @_variables ||= JSON.parse(job.variables)
    end

    def headers
      @_headers ||= JSON.parse(job.customHeaders)
    end

    def expect_input(data)
      job_variables = variables
      data = data.stringify_keys if data.is_a?(Hash)
      context.instance_eval do
        expect(job_variables).to match(data)
      end

      self
    end

    def expect_headers(headers)
      job_headers = self.headers
      headers = headers.stringify_keys if headers.is_a?(Hash)
      context.instance_eval do
        expect(job_headers).to match(headers)
      end

      self
    end

    def and_throw_error(error_code, message = nil)
      client.throw_error(ThrowErrorRequest.new(
                           {
                             jobKey: job.key,
                             errorCode: error_code,
                             errorMessage: message,
                           }.compact
                         ))
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

    def and_complete(variables = {})
      client.complete_job(CompleteJobRequest.new(
                            jobKey: job.key,
                            variables: variables.to_json
                          ))
    end

    private

    attr_reader :client, :context
  end
end
