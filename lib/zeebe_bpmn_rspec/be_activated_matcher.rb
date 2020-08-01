# frozen_string_literal: true

RSpec::Matchers.define :be_activated do
  class BeActivatedMatcherError < StandardError
    def initialize
      super("Only one of complete, fail, and throw error can be specified")
    end
  end

  match do |job|
    @job = job
    result = activated? && variables_match? && headers_match?

    if result
      if @complete
        job.complete(@output || {})
      elsif @fail
        job.fail(@fail_message, retries: @retries)
      elsif @throw
        job.throw_error(@error_code, @throw_message)
      end
    end

    result
  end

  failure_message do |job|
    aggregate_failures "expected activated job #{job}" do
      expect(job).not_to be_nil
      expect(job.variables).to match(@variables) if @variables
      expect(job.headers).to match(@headers) if @headers
    end
  end

  def activated?
    !job.nil?
  end

  attr_reader :job

  def variables_match?
    @variables.nil? || values_match?(@variables, job.variables)
  end

  def headers_match?
    @headers.nil? || values_match?(@headers, job.headers)
  end

  def predestined?
    @complete || @fail || @throw
  end

  chain :with_variables do |variables|
    @variables = variables.is_a?(Hash) ? variables.stringify_keys : variables
  end

  chain :with_headers do |headers|
    @headers = headers.is_a?(Hash) ? headers.stringify_keys : headers
  end

  chain :and_complete do |output = nil|
    raise BeActivatedMatcherError.new if predestined?

    @output = output
    @complete = true
  end

  chain :and_fail do |message = nil, retries: 0|
    raise BeActivatedMatcherError.new if predestined?

    @fail_message = message
    @retries = retries
    @fail = true
  end

  chain :and_throw_error do |error_code, message = nil|
    raise BeActivatedMatcherError.new if predestined?

    @error_code = error_code
    @throw_message = message
    @throw = true
  end
end