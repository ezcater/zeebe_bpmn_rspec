# frozen_string_literal: true

require "active_support"
require "active_support/core_ext/hash/keys"
require "json"

module ZeebeBpmnRspec
  class ActivatedJob
    include ::Zeebe::Client::GatewayProtocol # for direct reference of request classes

    attr_reader :job, :type, :workflow_instance_key

    def initialize(job, type:, workflow_instance_key:, client:, context:, validate:) # rubocop:disable Metrics/ParameterLists
      @job = job
      @type = type
      @workflow_instance_key = workflow_instance_key
      @client = client
      @context = context

      if validate
        context.instance_eval do
          expect(job).not_to be_nil, "expected to receive job of type '#{type}' but received none"
          aggregate_failures do
            expect(job.workflowInstanceKey).to eq(workflow_instance_key)
            expect(job.type).to eq(type)
          end
        end
      end
    end

    def raw
      job
    end

    def key
      job.key
    end

    def to_s
      raw.to_s
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
    alias throw_error and_throw_error

    def and_fail(message = nil, retries: nil)
      client.fail_job(FailJobRequest.new(
                        {
                          jobKey: job.key,
                          retries: retries || 0,
                          errorMessage: message,
                        }.compact
                      ))
    end
    alias fail and_fail

    def and_complete(variables = {})
      client.complete_job(CompleteJobRequest.new(
                            jobKey: job.key,
                            variables: variables.to_json
                          ))
    end
    alias complete and_complete

    private

    attr_reader :client, :context
  end
end
