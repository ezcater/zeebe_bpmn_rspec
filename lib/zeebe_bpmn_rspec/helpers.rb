# frozen_string_literal: true

require "zeebe_bpmn_rspec/activated_job"
require "zeebe_bpmn_rspec/activated_job_target"

module ZeebeBpmnRspec
  module Helpers # rubocop:disable Metrics/ModuleLength
    include ::Zeebe::Client::GatewayProtocol # for direct reference of request classes

    def deploy_workflow(path, name = nil)
      _zeebe_client.deploy_workflow(DeployWorkflowRequest.new(
                                      workflows: [WorkflowRequestObject.new(
                                        name: (name && "#{name}.bpmn") || File.basename(path),
                                        type: WorkflowRequestObject::ResourceType::FILE,
                                        definition: File.read(path)
                                      )]
                                    ))
    rescue StandardError => e
      raise "Failed to deploy workflow: #{e}"
    end

    def with_workflow_instance(name, variables = {})
      system_error = nil
      workflow = _zeebe_client.create_workflow_instance(CreateWorkflowInstanceRequest.new(
                                                          bpmnProcessId: name,
                                                          version: -1, # always latest
                                                          variables: variables.to_json
                                                        ))
      @__workflow_instance_key = workflow.workflowInstanceKey
      yield(workflow.workflowInstanceKey)
    rescue Exception => e # rubocop:disable Lint/RescueException
      # exceptions are rescued to ensure that instances are cancelled
      # any error is re-raised below
      system_error = e
    ensure
      if workflow&.workflowInstanceKey
        begin
          _zeebe_client.cancel_workflow_instance(CancelWorkflowInstanceRequest.new(
                                                   workflowInstanceKey: workflow.workflowInstanceKey
                                                 ))
        rescue GRPC::NotFound => _e
          # expected
        rescue StandardError => _e
          puts "Cancelled instance #{ex.inspect}" # TODO
        end
      end
      raise system_error if system_error
    end

    def workflow_complete!
      error = nil
      sleep 0.25 # TODO: configurable?
      begin
        _zeebe_client.cancel_workflow_instance(CancelWorkflowInstanceRequest.new(
                                                 workflowInstanceKey: workflow_instance_key
                                               ))
      rescue GRPC::NotFound => e
        error = e
      end

      raise "Expected workflow instance #{workflow_instance_key} to be complete" if error.nil?
    end

    def workflow_instance_key
      @__workflow_instance_key
    end

    def activate_job(type)
      stream = _zeebe_client.activate_jobs(ActivateJobsRequest.new(
                                             type: type,
                                             worker: "#{type}-#{SecureRandom.hex}",
                                             maxJobsToActivate: 1,
                                             timeout: 5000, # TODO: configure
                                             requestTimeout: 5000
                                           ))

      job = nil
      stream.find { |response| job = response.jobs.first }
      raise "No job with type #{type.inspect} found" if job.nil?

      # puts job.inspect # support debug logging?

      ActivatedJob.new(job,
                       type: type,
                       workflow_instance_key: workflow_instance_key,
                       client: _zeebe_client,
                       context: self)
    end
    alias process_job activate_job
    # TODO: deprecate process_job

    # TODO: better way to handle this!
    def job_with_type(type)
      ActivatedJobTarget.new(type, activate_job(type))
    rescue StandardError => e
      if e.message.match?(/^No job with type/)
        nil
      else
        raise
      end
    end

    def expect_job_of_type(type)
      expect(job_with_type(type))
    end

    def activate_jobs(type, max_jobs: nil)
      stream = _zeebe_client.activate_jobs(ActivateJobsRequest.new({
        type: type,
        worker: "#{type}-#{SecureRandom.hex}",
        maxJobsToActivate: max_jobs,
        timeout: 1000,
        requestTimeout: ZeebeBpmnRspec.activate_request_timeout,
      }.compact))

      Enumerator.new do |yielder|
        stream.each do |response|
          response.jobs.each do |job|
            yielder << ActivatedJob.new(job,
                                        type: type,
                                        workflow_instance_key: workflow_instance_key,
                                        client: _zeebe_client,
                                        context: self)
          end
        end
      end
    end

    def publish_message(name, correlation_key:, variables: nil)
      _zeebe_client.publish_message(PublishMessageRequest.new(
                                      {
                                        name: name,
                                        correlationKey: correlation_key,
                                        timeToLive: 5000,
                                        variables: variables&.to_json,
                                      }.compact
                                    ))
    end

    def reset_zeebe!
      @__workflow_instance_key = nil
    end

    private

    def _zeebe_client
      ZeebeBpmnRspec.client
    end
  end
end
