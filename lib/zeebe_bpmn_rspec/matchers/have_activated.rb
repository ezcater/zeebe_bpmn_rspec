# frozen_string_literal: true

require "zeebe_bpmn_rspec/matchers/have_variables"
require "zeebe_bpmn_rspec/matchers/have_headers"

module ZeebeBpmnRspec
  class HaveActivatedMatcherError < StandardError
    def initialize
      super("Only one of complete, fail, and throw error can be specified")
    end
  end
end

# rubocop:disable Metrics/BlockLength
RSpec::Matchers.define :have_activated do
  match do |job|
    @job = job

    @matcher_error = nil
    begin
      aggregate_failures "activated job#{of_type(job)}" do
        unless job.is_a?(ZeebeBpmnRspec::ActivatedJob)
          raise ArgumentError.new("expectation target must be a "\
                                  "#{ZeebeBpmnRspec::ActivatedJob.name}, got #{job.inspect}")
        end

        if job.raw.nil?
          raise RSpec::Expectations::ExpectationNotMetError.new("expected activated job#{of_type(job)}, got nil")
        end

        expect(job).to have_variables(@variables) if @variables
        expect(job).to have_headers(@headers) if @headers
      end
    rescue Exception => e # rubocop:disable Lint/RescueException
      @matcher_error = e
    end
    return false if @matcher_error

    if @complete
      job.complete(@output || {})
    elsif @fail
      job.fail(@fail_message, retries: @retries)
    elsif @throw
      job.throw_error(@error_code, @throw_message)
    end

    true
  end

  def of_type(job)
    job.respond_to?(:type) ? " of type #{job.type}" : nil
  end

  failure_message do |_job|
    raise matcher_error
  end

  attr_reader :job, :matcher_error

  def predestined?
    @complete || @fail || @throw
  end

  def check_predestined!
    raise ZeebeBpmnRspec::HaveActivatedMatcherError.new if predestined?
  end

  chain :with_variables do |variables|
    @variables = variables.is_a?(Hash) ? variables.stringify_keys : variables
  end

  chain :with_headers do |headers|
    @headers = headers.is_a?(Hash) ? headers.stringify_keys : headers
  end

  chain :and_complete do |output = nil|
    check_predestined!

    @output = output
    @complete = true
  end

  chain :and_fail do |message = nil, retries: 0|
    check_predestined!

    @fail_message = message
    @retries = retries
    @fail = true
  end

  chain :and_throw_error do |error_code, message = nil|
    check_predestined!

    @error_code = error_code
    @throw_message = message
    @throw = true
  end
end
# rubocop:enable Metrics/BlockLength
