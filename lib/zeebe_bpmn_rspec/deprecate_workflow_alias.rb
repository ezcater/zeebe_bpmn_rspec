# frozen_string_literal: true

require "active_support/deprecation"

module ZeebeBpmnRspec
  module DeprecateWorkflowAlias
    WorkflowDeprecation = ActiveSupport::Deprecation.new("v2.0", "ZeebeBpmnRspec")

    def deprecate_workflow_alias(deprecated_name, new_name)
      alias_method deprecated_name, new_name
      deprecate deprecated_name => new_name, deprecator: WorkflowDeprecation
    end
  end
end
