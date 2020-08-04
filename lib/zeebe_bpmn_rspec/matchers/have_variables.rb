# frozen_string_literal: true

RSpec::Matchers.define :have_variables do |expected|
  match do |actual|
    @job = actual
    @actual = @job.variables
    values_match?(expected, @actual)
  end

  failure_message do |_actual|
    "expected that #{@job} would have variables #{expected}"
  end

  diffable
end
