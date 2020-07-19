# frozen_string_literal: true

require "zeebe_bpmn_rspec/job_processor"

module ZeebeBpmnRspec
  module Helpers
    include ::Zeebe::Client::GatewayProtocol # for direct reference of request classes

    def deploy_workflow(path, name = nil)
      client.deploy_workflow(DeployWorkflowRequest.new(
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
      workflow = client.create_workflow_instance(CreateWorkflowInstanceRequest.new(
                                                   bpmnProcessId: name,
                                                   version: -1, # always latest
                                                   variables: variables.to_json
                                                 ))
      @__workflow_instance_key = workflow.workflowInstanceKey
      yield(workflow.workflowInstanceKey)
    rescue Exception => e
      system_error = e
    ensure
      if workflow&.workflowInstanceKey
        begin
          client.cancel_workflow_instance(CancelWorkflowInstanceRequest.new(
                                            workflowInstanceKey: workflow.workflowInstanceKey
                                          ))
        rescue StandardError => _e
          # TODO: log puts "Cancelled instance #{ex.inspect}"
          nil
        end
      end
      raise system_error if system_error
    end

    def workflow_complete!
      error = nil
      sleep 0.25 # TODO: configurable?
      begin
        client.cancel_workflow_instance(CancelWorkflowInstanceRequest.new(
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

    def process_job(type)
      stream = client.activate_jobs(ActivateJobsRequest.new(
                                      type: type,
                                      worker: "#{type}-#{SecureRandom.hex}",
                                      maxJobsToActivate: 1,
                                      timeout: 60000, # TODO: configure
                                      requestTimeout: 60000
                                    ))

      job = nil
      stream.find { |response| job = response.jobs.first }
      raise "No job with type #{type.inspect} found" if job.nil?

      # puts job.inspect # support debug logging?

      JobProcessor.new(job, type: type, workflow_instance_key: workflow_instance_key, client: client, context: self)
    end

    def publish_message(name, correlation_key:, variables: nil)
      client.publish_message(PublishMessageRequest.new(
                               {
                                 name: name,
                                 correlationKey: correlation_key,
                                 timeToLive: 60000,
                                 variables: variables&.to_json,
                               }.compact
                             ))
    end

    def reset_zeebe!
      @__workflow_instance_key = nil
    end

    private

    def client
      ZeebeBpmnRspec.client
    end
  end
end
