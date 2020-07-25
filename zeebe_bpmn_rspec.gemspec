# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "zeebe_bpmn_rspec/version"

Gem::Specification.new do |spec|
  spec.name          = "zeebe_bpmn_rspec"
  spec.version       = ZeebeBpmnRspec::VERSION
  spec.authors       = ["ezCater, Inc"]
  spec.email         = ["engineering@ezcater.com"]
  spec.summary       = "Zeebe BPMN testing using RSpec"
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/ezcater/zeebe_bpmn_rspec"

  spec.license       = "MIT"

  # Set "allowed_push_post" to control where this gem can be published.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  excluded_files = %w(.circleci/config.yml
                      .github/PULL_REQUEST_TEMPLATE.md
                      .gitignore
                      .rspec
                      .rubocop.yml
                      .ruby-gemset
                      .ruby-version
                      .travis.yml
                      bin/console
                      bin/setup
                      Rakefile)

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(/^(test|spec|features|compose)\//)
  end - excluded_files
  spec.bindir        = "bin"
  spec.executables   = []
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "ezcater_rubocop", "2.0.0"
  spec.add_development_dependency "overcommit"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec_junit_formatter", "0.2.2"
  spec.add_development_dependency "ruby-kafka"
  spec.add_development_dependency "simplecov", "< 0.18"

  spec.add_runtime_dependency "activesupport"
  spec.add_runtime_dependency "rspec", "~> 3.4"
  spec.add_runtime_dependency "zeebe-client"
end
