# frozen_string_literal: true

require "active_support/deprecation"

module ZeebeBpmnRspec
  module DeprecateWorkflowAlias
    AS_OF_VERSION_3 = ActiveSupport::Deprecation.new("3.0", "ZeebeBpmnRspec")

    def deprecate_workflow_alias(deprecated_name, new_name)
      alias_method deprecated_name, new_name
      deprecate deprecated_name => new_name, deprecator: AS_OF_VERSION_3
    end
  end
end
