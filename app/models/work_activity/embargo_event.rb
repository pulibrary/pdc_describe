# frozen_string_literal: true

class WorkActivity
  # Renderer for embargo-related activities
  #
  # Displays embargo events as system-generated activities
  class EmbargoEvent < BaseMessage
    # Override to show embargo events as created by "the system"
    #
    # @return [String] "the system"
    def created_by_user_html
      "the system"
    end
  end
end
