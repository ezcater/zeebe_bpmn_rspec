# frozen_string_literal: true

require "rspec"
require "zeebe/client"
require "zeebe_bpmn_rspec/helpers"
require "zeebe_bpmn_rspec/version"
require "zeebe_bpmn_rspec/matchers/have_activated_matcher"

# Top-level gem module
module ZeebeBpmnRspec
  class << self
    attr_writer :client, :zeebe_address, :activate_request_timeout

    def configure
      yield(self)
    end

    # rubocop:disable Naming/MemoizedInstanceVariableName
    def client
      @client ||= Zeebe::Client::GatewayProtocol::Gateway::Stub.new(zeebe_address, :this_channel_is_insecure)
    end
    # rubocop:enable Naming/MemoizedInstanceVariableName

    def zeebe_address
      @zeebe_address || ENV["ZEEBE_ADDRESS"] || (raise "zeebe_address must be set")
    end

    def activate_request_timeout
      @activate_request_timeout || 1000
    end
  end
end

RSpec.configure do |config|
  config.include ZeebeBpmnRspec::Helpers

  config.after(:each) do
    reset_zeebe!
  end
end
