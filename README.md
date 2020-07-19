# zeebe_bpmn_rspec

This gem provides support for testing BPMN files with the Zeebe workflow engine.

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

Either the address for the Zeebe workflow engine or a Zeebe client must be configured:

```ruby
ZeebeBpmnRspec.configure do |config|
  config.zeebe_address = "localhost:26500"
  # -OR-
  config.client = #<Zeebe::Client::GatewayProtocol::Gateway::Stub instance>
end
```

If `zeebe_address` is not set then the environment variable `ZEEBE_ADDRESS` is also checked.

## Usage

The gem adds the following method to RSpec.

### Deploy Workflow

The `deploy_workflow` requires a path to a BPMN file and deploys it to Zeebe. There is no support for
removing a BPMN file once deployed, so this can be done once before the examples that use it.

```ruby
before(:all) { deploy_workflow(filepath) }
```

A custom name can also be specified for the workflow:

```ruby
before(:all) { deploy_workflow(filepath, "custom_name") }
```

### With Workflow Instance



## Development

After checking out the repo, run `bin/setup` to install dependencies. Then,
run `rake spec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. 

To release a new version, update the version number in `version.rb`, and then
run `bundle exec rake release`, which will create a git tag for the version,
push git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org)
.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/ezcater/zeebe_bpmn_rspec.## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).

