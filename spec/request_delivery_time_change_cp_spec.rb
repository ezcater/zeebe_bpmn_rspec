# frozen_string_literal: true

require "securerandom"

RSpec.describe "request_delivery_time_change_cp BPMN" do # rubocop:disable RSpec/DescribeClass
  let(:cust_response_timeout) { "PT5S" }
  let(:cp_response_timeout) { "PT5S" }
  let(:user_uuid) { SecureRandom.uuid }
  let(:contact_uuid) { SecureRandom.uuid }
  let(:order_uuid) { SecureRandom.uuid }
  let(:start_variables) do
    {
      user_uuid: user_uuid,
      contact_uuid: contact_uuid,
      order_uuid: order_uuid,
      cust_response_timeout: cust_response_timeout,
      cp_response_timeout: cp_response_timeout,
    }.stringify_keys!
  end

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    path = File.join(__dir__, "fixtures/request_delivery_time_change_cp.bpmn")
    deploy_workflow(path)
  end

  around do |example|
    with_workflow_instance("request_delivery_time_change_cp", start_variables) do
      example.run
    end
  end

  context "when the customer approves the change" do
    context "when the caterer approves" do
      it "processes the workflow (happy path)" do
        # Task - notify customer
        process_job("send_communication").
          expect_input(start_variables).
          expect_headers(comm_name: "request_delivery_time_change_notify_cust_of_request",
                         identity_key: "user_uuid",
                         identity_type: "user").
          and_complete(cust_response_decision_id: (decision_id = SecureRandom.uuid))

        # Message - customer response
        publish_message("decision_completed",
                        correlation_key: decision_id,
                        variables: { response: true })

        # Task - notify cp
        process_job("send_communication").
          expect_input(hash_including("cust_approved" => true, "contact_uuid" => contact_uuid)).
          expect_headers(comm_name: "request_delivery_time_change_notify_cp_cust_approved",
                         identity_key: "contact_uuid",
                         identity_type: "contact").
          and_complete(cp_response_decision_id: (decision_id = SecureRandom.uuid))

        # Message - contact response
        publish_message("decision_completed",
                        correlation_key: decision_id,
                        variables: { response: true })

        # Task - update order
        process_job("update_delivery_time").
          expect_input(hash_including("cp_approved" => true, "order_uuid" => order_uuid)).
          expect_headers({}).
          and_complete

        # Task - notify contact
        process_job("send_communication").
          expect_headers(comm_name: "request_delivery_time_change_notify_cp_change_complete",
                         identity_key: "contact_uuid",
                         identity_type: "contact").
          and_complete

        # Task - notify customer
        process_job("send_communication").
          expect_headers(comm_name: "request_delivery_time_change_notify_cust_change_complete",
                         identity_key: "user_uuid",
                         identity_type: "user").
          and_complete

        # Assert complete
        workflow_complete!
      end

      it "happy path -- alternate" do
        # Task - notify customer
        process_job("send_communication").
          expect_input(start_variables).
          expect_headers(comm_name: "request_delivery_time_change_notify_cust_of_request",
                         identity_key: "user_uuid",
                         identity_type: "user").
          and_complete(cust_response_decision_id: (decision_id = SecureRandom.uuid))

        # Message - customer response
        publish_message("decision_completed",
                        correlation_key: decision_id,
                        variables: { response: true })

        # Task - notify cp
        process_job("send_communication").
          expect_input(hash_including("cust_approved" => true, "contact_uuid" => contact_uuid)).
          expect_headers(comm_name: "request_delivery_time_change_notify_cp_cust_approved",
                         identity_key: "contact_uuid",
                         identity_type: "contact").
          and_complete(cp_response_decision_id: (decision_id = SecureRandom.uuid))

        # Message - contact response
        publish_message("decision_completed",
                        correlation_key: decision_id,
                        variables: { response: true })

        # Task - update order
        process_job("update_delivery_time").
          expect_input(hash_including("cp_approved" => true, "order_uuid" => order_uuid)).
          expect_headers({}).
          and_complete

        # Tasks - 2 expect: customer and contact
        jobs = activate_jobs("send_communication", max_jobs: 2).to_a

        contact_job = jobs.find { |job| job.headers["identity_type"] == "contact" }
        user_job = jobs.find { |job| job.headers["identity_type"] == "user" }

        # Task - notify contact
        contact_job.
          expect_headers(comm_name: "request_delivery_time_change_notify_cp_change_complete",
                         identity_key: "contact_uuid",
                         identity_type: "contact").
          and_complete

        # Task - notify customer
        user_job.
          expect_headers(comm_name: "request_delivery_time_change_notify_cust_change_complete",
                         identity_key: "user_uuid",
                         identity_type: "user").
          and_complete

        # Assert complete
        workflow_complete!
      end
    end

    context "when the caterer rejects" do
      it "creates a liberty task and resets the caterer decision" do
        # Task - notify customer
        activate_job("send_communication").
          expect_input(start_variables).
          expect_headers(comm_name: "request_delivery_time_change_notify_cust_of_request",
                         identity_key: "user_uuid",
                         identity_type: "user").
          and_complete(cust_response_decision_id: (decision_id = SecureRandom.uuid))

        # Message - customer response
        publish_message("decision_completed",
                        correlation_key: decision_id,
                        variables: { response: true })

        # Task - notify cp
        activate_job("send_communication").
          expect_input(hash_including("cust_approved" => true, "contact_uuid" => contact_uuid)).
          expect_headers(comm_name: "request_delivery_time_change_notify_cp_cust_approved",
                         identity_key: "contact_uuid",
                         identity_type: "contact").
          and_complete(cp_response_decision_id: (decision_id = SecureRandom.uuid))

        # Message - contact response
        publish_message("decision_completed",
                        correlation_key: decision_id,
                        variables: { response: false })

        # Task - create liberty task
        activate_job("create_liberty_task").
          expect_headers(context: "CP rejected change request",
                         task_type: "REJECTED_REQUEST").
          and_complete

        # Task - reset decision
        activate_job("reset_decision").
          expect_headers(decision_id_key: "cp_response_decision_id").
          and_complete

        # workflow_complete!
      end
    end
  end

  context "when the customer rejects the change" do
    it "creates a liberty task and resets the decision" do
      # Task - notify customer
      process_job("send_communication").
        expect_input(start_variables).
        expect_headers(comm_name: "request_delivery_time_change_notify_cust_of_request",
                       identity_key: "user_uuid",
                       identity_type: "user").
        and_complete(cust_response_decision_id: (decision_id = SecureRandom.uuid))

      # Message - customer response
      publish_message("decision_completed",
                      correlation_key: decision_id,
                      variables: { response: false })

      # Task - create liberty task
      process_job("create_liberty_task").
        expect_headers({
          context: "Customer rejected change request",
          task_type: "REJECTED_REQUEST",
        }).
        and_complete

      # Task - reset decision
      process_job("reset_decision").
        expect_headers(decision_id_key: "cust_response_decision_id").
        and_complete

      # workflow_complete!
    end
  end

  context "when the workflow times out waiting for the customer response" do
    let(:cust_response_timeout) { "PT1S" }

    it "creates a liberty task" do
      # Task - notify customer
      process_job("send_communication").
        expect_input(start_variables).
        expect_headers(comm_name: "request_delivery_time_change_notify_cust_of_request",
                       identity_key: "user_uuid",
                       identity_type: "user").
        and_complete(cust_response_decision_id: (_decision_id = SecureRandom.uuid))

      # Task - create liberty task
      process_job("create_liberty_task").
        expect_headers(context: "Timed out waiting for customer response",
                       task_type: "NO_RESPONSE").and_complete

      # workflow_complete!
    end
  end
end
