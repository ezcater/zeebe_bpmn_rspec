# zeebe_bpmn_rspec

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
`ZEEBE_ADDRESS` if used from the environment if this is not configured.

```ruby
ZeebeBpmnRspec.configure do |config|
  config.zeebe_address = "localhost:26500"
  # -OR-
  config.client = #<Zeebe::Client::GatewayProtocol::Gateway::Stub instance>
end
```

## Usage

The gem adds the following helper methods to RSpec.

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

Jobs can be completed by calling `and_complete`. Variables can optionally be returned with the
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

Jobs can be failed by calling `and_fail`. An optional message can be specified when failing a job.

```ruby
# Failing a job can be chanined with expectations
activate_job("my_job").
  expect_headers(id_type: "user").
  and_fail

# Jobs can be failed with a message
activate_job("my_job").
  and_fail("something didn't go right")
```

#### Throw Error

The `and_throw_error` method can be used to throw an error for a job. The error code is required and an
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

TODO

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

