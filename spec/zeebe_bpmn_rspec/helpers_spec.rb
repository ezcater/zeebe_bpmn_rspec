# frozen_string_literal: true

require "securerandom"
require "active_support"
require "active_support/core_ext/hash/keys"

RSpec.describe ZeebeBpmnRspec::Helpers do
  let(:path) { File.join(__dir__, "../fixtures/#{bpmn_name}.bpmn") }
  let(:bpmn_name) { "one_task" }
  let(:deploy) { true }

  before { deploy_workflow(path) if deploy }

  describe "#deploy_workflow" do
    let(:deploy) { false }

    it "can deploy a workflow" do
      response = deploy_workflow(path)

      workflow = response.workflows.find do |wf|
        wf.resourceName == "#{bpmn_name}.bpmn"
      end
      expect(workflow).not_to be_nil
    end

    context "when a name is specified" do
      let(:name) { SecureRandom.hex }

      it "deploys the workflow with that name" do
        response = deploy_workflow(path, name)

        workflow = response.workflows.find do |wf|
          wf.resourceName == "#{name}.bpmn"
        end
        expect(workflow).not_to be_nil
      end
    end
  end

  describe "#with_workflow_instance" do
    it "can run a workflow instance" do
      key = nil
      with_workflow_instance("one_task") do |workflow_instance_key|
        key = workflow_instance_key
      end

      expect(key).to eq(workflow_instance_key)
    end
  end

  describe "#workflow_complete!" do
    it "can assert that a workflow is complete" do
      with_workflow_instance("one_task") do
        activate_job("do_something").and_complete

        workflow_complete!
      end
    end
  end

  describe "#activate_job" do
    it "can activate a job" do
      with_workflow_instance("one_task", { input: 1 }) do
        job = activate_job("do_something")

        expect(job.variables).to eq("input" => 1)
        expect(job.headers).to eq("what_to_do" => "nothing")
      end
    end
  end

  describe "ActivatedJob#expect_input" do
    it "can check the variables for a job" do
      with_workflow_instance("one_task", { a: 99, b: "c" }) do
        activate_job("do_something").expect_input(a: 99, b: "c")
      end
    end
  end

  describe "ActivatedJob#expect_headers" do
    it "can check the headers for a job" do
      with_workflow_instance("one_task", { a: 99, b: "c" }) do
        activate_job("do_something").expect_headers(what_to_do: "nothing")
      end
    end
  end

  describe "ActivatedJob#and_complete" do
    it "can complete a job" do
      with_workflow_instance("one_task") do
        activate_job("do_something").and_complete

        workflow_complete!
      end
    end

    context "when new variables are specified" do
      let(:bpmn_name) { :two_tasks }

      it "can complete a job with new variables" do
        with_workflow_instance("two_tasks") do
          activate_job("do_something").
            and_complete(return: (value = SecureRandom.hex))

          activate_job("next_step").
            expect_input(return: value)
        end
      end
    end
  end

  describe "ActivatedJob#and_fail" do
    it "can fail a job" do
      with_workflow_instance("one_task") do
        activate_job("do_something").
          and_fail(retries: 1)

        activate_job("do_something").and_complete

        workflow_complete!
      end
    end

    it "can fail a job with a message" do
      with_workflow_instance("one_task") do
        activate_job("do_something").
          and_fail("foobar", retries: 1)

        activate_job("do_something").and_complete

        workflow_complete!
      end
    end
  end

  describe "ActivatedJob#and_throw_error" do
    it "can throw an error for a job" do
      with_workflow_instance("one_task") do
        job = activate_job("do_something")

        job.throw_error("ERROR_BOOM")

        # should fail since there was already an error
        expect do
          job.fail("boo!")
        end.to raise_error(/in state 'ERROR_THROWN'/)
      end
    end

    it "can throw an error for a job with an error message" do
      with_workflow_instance("one_task") do
        activate_job("do_something").
          and_throw_error("ERROR_BOOM", "chickaboom")
      end
    end
  end

  describe "#activate_jobs" do
    let(:bpmn_name) { "parallel_tasks" }

    it "can activate multiple jobs" do
      with_workflow_instance("parallel_tasks") do
        activate_job("do_something").and_complete

        jobs = activate_jobs("parallel", max_jobs: 2).to_a

        job_one = jobs.find { |job| job.headers["branch"] == "one" }
        job_two = jobs.find { |job| job.headers["branch"] == "two" }

        expect(job_one).not_to be nil
        expect(job_two).not_to be nil

        jobs.map(&:complete)

        workflow_complete!
      end
    end
  end

  describe "#publish_message" do
    let(:bpmn_name) { :message_receive }

    it "can publish a message" do
      with_workflow_instance("message_receive", expected_message_key: (key = SecureRandom.uuid)) do
        publish_message("expected_message", correlation_key: key)

        workflow_complete!
      end
    end
  end
end
