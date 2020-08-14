# frozen_string_literal: true

RSpec::Matchers.define :have_headers do
  match do |actual|
    @job = actual
    @actual = @job.headers
    values_match?(expected, @actual)
  end

  failure_message do |_actual|
    "expected that job:\n  #{@job}\n\nwould have headers #{expected}"
  end

  diffable
end
