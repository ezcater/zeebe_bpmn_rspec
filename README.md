# zeebe_bpmn_rspec

[![](https://img.shields.io/badge/Community%20Extension-An%20open%20source%20community%20maintained%20project-FF4700)](https://github.com/camunda-community-hub/community)

[![](https://img.shields.io/badge/Lifecycle-Stable-brightgreen)](https://github.com/Camunda-Community-Hub/community/blob/main/extension-lifecycle.md#stable-) 
[![License](https://img.shields.io/badge/License-MIT-green)](https://opensource.org/licenses/MIT)

This gem provides support for testing BPMN files using RSpec with the Zeebe workflow engine.

The gem adds RSpec helpers that are used to interact with Zeebe and a running workflow instance.

## Installation

Add this line to the test group in your application's Gemfile:

```ruby
group :test do
  gem "zeebe_bpmn_rspec"
end
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install zeebe_bpmn_rspec

## Configuration

Either the address for the Zeebe workflow engine or a Zeebe client must be configured.
`ZEEBE_ADDRESS` is used from the environment if this is not configured.

```ruby
ZeebeBpmnRspec.configure do |config|
  config.zeebe_address = "localhost:26500"
  # -OR-
  config.client = #<Zeebe::Client::GatewayProtocol::Gateway::Stub instance>
end
```

## Usage

The gem adds the following helper methods to RSpec.

The gem also defines [Custom Matchers](#custom-matchers).

### Deploy Workflow

The `deploy_workflow` method requires a path to a BPMN file and deploys it to Zeebe. There is no support for
removing a BPMN file once deployed, so this can be done once before the examples that use it.

```ruby
before(:all) { deploy_workflow(filepath) }
```

A custom name can also be specified for the workflow:

```ruby
before(:all) { deploy_workflow(filepath, "custom_name") }
```

### With Workflow Instance

The `with_workflow_instance` method is used to create an instance for the specified workflow
and then yields a block that can interact with the instance.

This method ensures that an active instance is cancelled at the end of the block.

For testing BPMN files it is expected that most of the test definition will be wrapped in a
call to this method.

```ruby
with_workflow_instance("file_basename") do
  ...
end
```

### Processing Jobs

A single job can be processed for a workflow by calling `activate_job` (previously `process_job`).
`activate_job` is called with a job type:

```ruby
activate_job("my_job")
```

The call to `activate_job` returns a `ActivatedJob` object that provides a fluent interface to chain
additional expectations and responses onto the job.

#### Expect Input

To check the input variables that are passed to the job add `.expect_input`:

```ruby
activate_job("my_job").
  expect_input(user_id: 123)
```

Expect input uses RSpec expectations so it supports other RSpec helpers. For example, to perform
a partial match on the input:

```ruby
activate_job("my_job").
  expect_input(hash_including("user_id" => 123))
```

Note: that when using methods like `hash_including` string keys must be used to match the parsed JSON
coming from Zeebe.

#### Expect Headers

Similar to `expect_input`, expectations can be set on headers for the job using `.expect_headers`:

```ruby
activate_job("my_job").
  expect_headers(content_type: "CREATE")

# Combined with expect_input
activate_job("my_job").
  expect_input(user_id: 123).
  expect_headers(content_type: "CREATE")
```

#### Complete Job

Jobs can be completed by calling `and_complete` (also aliased as `complete`). Variables can optionally be returned with the
completed job.

```ruby
# Completing a job can be changed with expectations
activate_job("my_job").
  expect_input(user_id: 123).
  and_complete

# Jobs can be completed with data that is merged with variables in the workflow
project_job("my_job").
  and_complete(status: "ACTIVATED")
```

#### Fail Job

Jobs can be failed by calling `and_fail` (also aliased as `fail`). An optional message can be specified when failing a job.

```ruby
# Failing a job can be chanined with expectations
activate_job("my_job").
  expect_headers(id_type: "user").
  and_fail

# Jobs can be failed with a message
activate_job("my_job").
  and_fail("something didn't go right")
```

By default retries are set to zero when a job is failed but the remaining retries can optionally be specified:

```ruby
job = activate_job("my_job")

job.fail(retries: 1)
```

#### Update Retries

The retries for a job can also be modified using the `update_retries` method:

```ruby
job = activate_job("my_job")

job.update_retries(3)
```

#### Throw Error

The `and_throw_error` (also aliased as `throw_error`) method can be used to throw an error for a job. The error code is required and an
optional message may be specified:

```ruby
activate_job("my_job").
  expect_input(foo: "bar").
  and_throw_error("NOT_FOUND")

# with message
activate_job("my_job").
  expect_input(foo: "bar").
  and_throw_error("NOT_FOUND", "couldn't find a bar")
```

#### Activating Multiple Jobs

Multiple jobs can be activated using the `activate_jobs` method.

```ruby
activate_jobs("my_job")
```

The call to `activate_jobs` returns an Enumerator that returns `ActivatedJob` instances.
The maximum number of jobs to return can be specified:

```ruby
jobs = activate_jobs("my_job", max_jobs: 2).to_a
```

### Workflow Complete

The `workflow_complete!` method can be used to assert that the current workflow is complete at the end of a
test. This is implemented by cancelling the workflow and checking for an error that it is already
complete.

```ruby
with_workflow_instance("file_basename") do
  ...

  workflow_complete!
end
```

### Publish Message

The `publish_message` method is used to send a message to Zeebe.

The message name and correlation key are required:

```ruby
publish_message("message_name", correlation_key: expected_value)
```

Variables can also be sent with a message:

```ruby
publish_message("message_name", correlation_key: expected_value,
                variables: { foo: "bar" })
```

The time-to-live (in milliseconds) cna also be specified for a message.
It defaults to 5000 milliseconds if unspecified.

```ruby
publish_message("message_name", correlation_key: expected_value, ttl_ms: 1000)
```

### Set Variables

The `set_variables` method can be used to set variables for a specified
scope in Zeebe:

```ruby
# workflow_instance_key is a method that returns the key for the current workflow instance
set_variables(workflow_instance_key, { foo: "bar" })
```

An activated job can be used to determine the key for the task that it is associated with:

```ruby
job = job_with_type("my_type")
set_variables(job.task_key, { foo: "baz"})
```

Variables default to being local to the scope on which they are set. This
can be overridden by specifying the `:local` option:

```ruby
set_variables(job.task_key, { foo: "baz"}, local: false)
```

### Custom Matchers

In addition to the helpers documented above, this gem defines custom RSpec matchers to provide a more typical
experience of expectations and matchers.

#### expect_job_of_type

The `expect_job_of_type` helper is a convenient wrapper to activate a job and set an expectation target.

```ruby
expect_job_of_type("my_type")
```

Similar to the `activate_job` helper, it activates a job and wraps the result in an `ActivatedJob` object.
That object is then passed to `expect()`. Unlike `activate_job`, this helper does not raise if there is no job activated.

This is equivalent to `expect(job_with_type("my_type")` or `expect(activate_job("my_type", validate: false))`.

`expect_job_of_type` is expected to be used with the matchers below.

#### have_activated

The `have_activated` matcher checks that the target represents an activated job. It will raise an error if no job
was activated.

```ruby
expect_job_of_type("my_type").to have_activated
```

Various additional methods can be chained on the `have_activated` matcher.

The `with_variables` method can be used to check the input variables that the job was activated with:

```ruby
expect_job_of_type("my_type").to have_activated.with_variables(user_id: 123)
```

The `with_headers` method can be used to check the headers that the job was activated with:

```ruby
expect_job_of_type("my_type").to have_activated.with_headers(id_type: "user")
```

The `with_variables` and `with_headers` methods can be chained on the same expectation:

```ruby
expect_job_of_type("my_type").to have_activated.
                                   with_variables(user_id: 123).
                                   with_headers(id_type: "user")
```

The matcher also supports methods to complete, fail, or throw an error for a job:

```ruby
# Complete
expect_job_of_type("my_type").to have_activated.and_complete

# Complete with new variables
expect_job_of_type("my_type").to have_activated.and_complete(result_code: 456)

# Fail (sets retries to 0 by default)
expect_job_of_type("my_type").to have_activated.and_fail

# Fail and specify retries
expect_job_of_type("my_type").to have_activated.and_fail(retries: 1)

# Fail with an error message
expect_job_of_type("my_type").to have_activated.and_fail("boom!")

# Fail with an error message and specify retries
expect_job_of_type("my_type").to have_activated.and_fail("boom!", retries: 2)

# Throw an error (error code is required)
expect_job_of_type("my_type").to have_activated.and_throw_error("MY_ERROR")

# Throw an error with an error message
expect_job_of_type("my_type").to have_activated.and_throw_error("MY_ERROR", "went horribly wrong")
```

Only one of `and_complete`, `and_fail`, or `and_throw_error` can be specified for a single expectation.

#### have_variables and have_headers

In addition to the `with_variables` and `with_headers` methods that can be chained onto the `have_activated`
matcher, there are matchers that can be used directly to set expectations on the variables or
headers for an `ActivatedJob`.

```ruby
job = activate_job("my_type")

expect(job).to have_variables(user: 123)
expect(job).to have_headers(id_type: "user")
```

## Tips & Tricks

### Enumerator for Multiple Jobs

When activating multiple jobs, call `to_a` on the result of `activate_jobs` to get
an array of activated jobs objects.

### Timer Duration

Specify timer durations using a variable so that tests can easily set the variable
to specify a short duration.

## Limitations

The current gem and approach have some limitations:

1. You can interact with only one workflow at a time.

## Development

This repo contains a docker-compose file that starts Zeebe and can be used for
local development. Docker and Docker Compose most be installed as prerequisites.

Run the following to start a bash session. Gems will automatically be bundled and
the environment will have access to a running Zeebe broker:

```bash
docker-compose run --rm console bash
```

To run specs using docker-compose run the following command:

```bash
docker-compose run --rm console rspec
```

### Install Locally

To install this gem onto your local machine, run `bundle exec rake install`. 

### Create a Release

To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/ezcater/zeebe_bpmn_rspec.

## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

