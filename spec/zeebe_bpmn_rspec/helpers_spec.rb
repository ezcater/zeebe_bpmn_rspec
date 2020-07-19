# frozen_string_literal: true

require "securerandom"
require "active_support"
require "active_support/core_ext/hash/keys"

RSpec.describe ZeebeBpmnRspec::Helpers do
  describe "deploy_workflow" do
    let(:path) { File.join(__dir__, "../fixtures/request_order_item_change_cp.bpmn") }
    let(:name) { File.basename(path, ".bpmn") }

    it "deploys a workflow" do
      response = deploy_workflow(path)

      workflow = response.workflows.find do |workflow|
        workflow.resourceName == "#{name}.bpmn"
      end
      expect(workflow).not_to be_nil
    end

    context "when a name is specified" do
      let(:name) { SecureRandom.hex }

      it "deploys the workflow with that name" do
        response = deploy_workflow(path, name)

        workflow = response.workflows.find do |workflow|
          workflow.resourceName == "#{name}.bpmn"
        end
        expect(workflow).not_to be_nil
      end
    end
  end

  describe "#with_workflow_instance" do
    let(:path) { File.join(__dir__, "../fixtures/request_order_item_change_cp.bpmn") }

    before do
      deploy_workflow(path)
    end

    it "creates a workflow instance and yields the key" do
      key = nil
      with_workflow_instance("request_order_item_change_cp") do |workflow_instance_key|
        key = workflow_instance_key
      end

      expect(key).to eq(workflow_instance_key)
    end
  end

  describe "#publish_message" do
    # TODO
  end

  describe "#workflow_complete!" do
    # TODO
  end

  describe "#process_job" do
    let(:path) { File.join(__dir__, "../fixtures/request_order_item_change_cp.bpmn") }
    let(:cust_response_timeout) { "PT60S" }

    before do
      deploy_workflow(path)
    end

    it "processes a job" do
      user_uuid = SecureRandom.uuid
      request_id = SecureRandom.uuid

      variables = {
        user_uuid: user_uuid,
        request_id: request_id,
        cust_response_timeout: cust_response_timeout,
      }.stringify_keys!

      with_workflow_instance("request_order_item_change_cp", variables) do
        process_job("send_communication").
          with(variables).
          with_headers({
            comm_name: "request_order_item_change_notify_cust_of_request",
            identity_key: "user_uuid",
            identity_type: "user",
          }.stringify_keys!).
          and_complete

        publish_message("all_decisions_completed",
                        correlation_key: request_id,
                        variables: { response: :yes })

        process_job("create_liberty_task").
          with_headers({
            context: "...",
            task_type: "...",
          }.stringify_keys!).
          and_complete
      end
    end

    it "processes a job with a timeout" do
      user_uuid = SecureRandom.uuid
      request_id = SecureRandom.uuid

      variables = {
        user_uuid: user_uuid,
        request_id: request_id,
        cust_response_timeout: "PT1S",
      }.stringify_keys!

      with_workflow_instance("request_order_item_change_cp", variables) do
        process_job("send_communication").
          with(variables).
          with_headers({
            comm_name: "request_order_item_change_notify_cust_of_request",
            identity_key: "user_uuid",
            identity_type: "user",
          }.stringify_keys!).
          and_complete

        process_job("create_liberty_task").
          with_headers({ task_type: "NO_RESPONSE", context: "Timed out waiting for customer responses" }.stringify_keys!).
          and_complete
      end
    end
  end
end
