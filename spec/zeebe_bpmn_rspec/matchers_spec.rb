# frozen_string_literal: true

RSpec.describe "Matchers" do # rubocop:disable RSpec/DescribeClass
  let(:path) { File.join(__dir__, "../fixtures/#{bpmn_name}.bpmn") }
  let(:bpmn_name) { "one_task" }
  let(:start_variables) { { a: 99, b: "c" } }

  around do |example|
    deploy_workflow(path)
    with_workflow_instance(bpmn_name, start_variables) do
      example.run
    end
  end

  it "can check that a job was activated" do
    expect_job_of_type("do_something").to have_activated
  end

  it "errors if a job was not activated" do
    expect do
      expect_job_of_type("does_not_exist").to have_activated
    end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected activated job/)
  end

  it "can check the variables for a job" do
    expect_job_of_type("do_something").to have_activated.with_variables(start_variables)
  end

  it "fails if the variables do not match the expected" do
    expect do
      expect_job_of_type("do_something").to have_activated.with_variables(c: 1)
    end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /have variables/)
  end

  it "can check the headers for a job" do
    expect_job_of_type("do_something").to have_activated.with_headers(what_to_do: "nothing")
  end

  it "fails if the headers do not match the expected" do
    expect do
      expect_job_of_type("do_something").to have_activated.
        with_headers(what_to_do: "something")
    end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /have headers/)
  end

  it "can check both variables and headers" do
    expect do
      expect_job_of_type("do_something").to have_activated.
        with_variables(c: 1).
        with_headers(what_to_do: "something")
    end.to raise_error(RSpec::Expectations::MultipleExpectationsNotMetError, /expected activated job/)
  end

  it "can complete a job" do
    expect_job_of_type("do_something").to have_activated.and_complete

    workflow_complete!
  end

  context "when new variables are specified" do
    let(:start_variables) { Hash.new }
    let(:bpmn_name) { :two_tasks }

    it "can complete a job with new variables" do
      expect_job_of_type("do_something").to have_activated.
        and_complete(return: (value = SecureRandom.hex))

      expect_job_of_type("next_step").to have_activated.
        with_variables(return: value)
    end
  end

  it "can fail a job" do
    expect_job_of_type("do_something").to have_activated.
      and_fail(retries: 1)

    expect_job_of_type("do_something").to have_activated.and_complete
  end

  it "can fail a job with a message" do
    expect_job_of_type("do_something").to have_activated.
      and_fail("foobar", retries: 1)

    expect_job_of_type("do_something").to have_activated.and_complete
  end

  it "can throw an error for a job" do
    job = job_with_type("do_something")

    expect(job).to have_activated.and_throw_error("ERROR_BOOM")

    # should fail since there was already an error
    expect do
      job.fail("boo!")
    end.to raise_error(/in state 'ERROR_THROWN'/)
  end

  it "can throw an error for a job with an error message" do
    expect_job_of_type("do_something").to have_activated.
      and_throw_error("ERROR_BOOM", "chickaboom")
  end

  it "raises an error if more than one of complete, fail, and throw_error is specified" do
    expect do
      expect_job_of_type("do_something").to have_activated.and_complete.and_fail
    end.to raise_error(ZeebeBpmnRspec::HaveActivatedMatcherError)
  end
end
