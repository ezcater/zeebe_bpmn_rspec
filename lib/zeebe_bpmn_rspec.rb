# frozen_string_literal: true

require "rspec"
require "zeebe/client"
require "zeebe_bpmn_rspec/helpers"
require "zeebe_bpmn_rspec/version"

# Top-level gem module
module ZeebeBpmnRspec
  class << self
    attr_writer :client, :zeebe_address
    attr_accessor :zeebe_address

    def configure
      yield(self)
    end

    def client
      @client ||= Zeebe::Client::GatewayProtocol::Gateway::Stub.new(zeebe_address, :this_channel_is_insecure)
    end

    def zeebe_address
      @zeebe_address || ENV["ZEEBE_ADDRESS"] || (raise "zeebe_address must be set")
    end
  end
end

RSpec.configure do |config|
  config.include ZeebeBpmnRspec::Helpers

  config.after(:each) do
    reset_zeebe!
  end
end
