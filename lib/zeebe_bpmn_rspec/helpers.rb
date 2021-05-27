# frozen_string_literal: true

require "active_support/core_ext/object/blank"
require "zeebe_bpmn_rspec/activated_job"

module ZeebeBpmnRspec
  module Helpers # rubocop:disable Metrics/ModuleLength
    include ::Zeebe::Client::GatewayProtocol # for direct reference of request classes
    extend DeprecateWorkflowAlias

    def deploy_process(path, name = nil)
      _zeebe_client.deploy_process(DeployProcessRequest.new(
                                     processes: [ProcessRequestObject.new(
                                       name: (name && "#{name}.bpmn") || File.basename(path),
                                       definition: File.read(path)
                                     )]
                                   ))
    rescue StandardError => e
      raise "Failed to deploy precess: #{e}"
    end
    deprecate_workflow_alias :deploy_workflow, :deploy_process

    def with_process_instance(name, variables = {})
      system_error = nil
      process = _zeebe_client.create_process_instance(CreateProcessInstanceRequest.new(
                                                        bpmnProcessId: name,
                                                        version: -1, # always latest
                                                        variables: variables.to_json
                                                      ))
      @__process_instance_key = process.processInstanceKey
      yield(process.processInstanceKey) if block_given?
    rescue Exception => e # rubocop:disable Lint/RescueException
      # exceptions are rescued to ensure that instances are cancelled
      # any error is re-raised below
      system_error = e
    ensure
      if process&.processInstanceKey
        begin
          _zeebe_client.cancel_process_instance(CancelProcessInstanceRequest.new(
                                                  processInstanceKey: process.processInstanceKey
                                                ))
        rescue GRPC::NotFound => _e
          # expected
        rescue StandardError => _e
          puts "Cancelled instance #{ex.inspect}" # TODO
        end
      end
      raise system_error if system_error
    end
    deprecate_workflow_alias :with_workflow_instance, :with_process_instance

    def process_complete!(wait_seconds: 0.25)
      error = nil
      sleep(wait_seconds)
      begin
        _zeebe_client.cancel_process_instance(CancelProcessInstanceRequest.new(
                                                processInstanceKey: process_instance_key
                                              ))
      rescue GRPC::NotFound => e
        error = e
      end

      raise "Expected process instance #{process_instance_key} to be complete" if error.nil?
    end
    deprecate_workflow_alias :workflow_complete!, :process_complete!

    def process_instance_key
      @__process_instance_key
    end
    deprecate_workflow_alias :workflow_instance_key, :process_instance_key

    def activate_job(type, fetch_variables: nil, validate: true, worker: "#{type}-#{SecureRandom.hex}")
      raise ArgumentError.new("'worker' cannot be blank") if worker.blank?

      stream = _zeebe_client.activate_jobs(ActivateJobsRequest.new({
        type: type,
        worker: worker,
        maxJobsToActivate: 1,
        timeout: 1000,
        fetchVariable: fetch_variables&.then { |v| Array(v) },
        requestTimeout: ZeebeBpmnRspec.activate_request_timeout,
      }.compact))

      job = nil
      stream.find { |response| job = response.jobs.first }
      # puts job.inspect # support debug logging?

      ActivatedJob.new(job,
                       type: type,
                       process_instance_key: process_instance_key,
                       client: _zeebe_client,
                       context: self,
                       validate: validate)
    end
    alias process_job activate_job
    deprecate process_job: :activate_job

    def job_with_type(type, fetch_variables: nil)
      activate_job(type, fetch_variables: fetch_variables, validate: false)
    end

    def expect_job_of_type(type, fetch_variables: nil)
      expect(job_with_type(type, fetch_variables: fetch_variables))
    end

    def activate_jobs(type, max_jobs: nil, fetch_variables: nil)
      stream = _zeebe_client.activate_jobs(ActivateJobsRequest.new({
        type: type,
        worker: "#{type}-#{SecureRandom.hex}",
        maxJobsToActivate: max_jobs,
        timeout: 1000,
        fetchVariable: fetch_variables&.then { |v| Array(v) },
        requestTimeout: ZeebeBpmnRspec.activate_request_timeout,
      }.compact))

      Enumerator.new do |yielder|
        stream.each do |response|
          response.jobs.each do |job|
            yielder << ActivatedJob.new(job,
                                        type: type,
                                        process_instance_key: process_instance_key,
                                        client: _zeebe_client,
                                        context: self,
                                        validate: true)
          end
        end
      end
    end

    def publish_message(name, correlation_key:, variables: nil, ttl_ms: 5000)
      _zeebe_client.publish_message(PublishMessageRequest.new(
                                      {
                                        name: name,
                                        correlationKey: correlation_key,
                                        timeToLive: ttl_ms,
                                        variables: variables&.to_json,
                                      }.compact
                                    ))
    end

    def set_variables(key, variables, local: true)
      _zeebe_client.set_variables(SetVariablesRequest.new(
                                    elementInstanceKey: key,
                                    variables: variables.to_json,
                                    local: local
                                  ))
    end

    def reset_zeebe!
      @__process_instance_key = nil
    end

    private

    def _zeebe_client
      ZeebeBpmnRspec.client
    end
  end
end
