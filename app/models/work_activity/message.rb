# frozen_string_literal: true

class WorkActivity
  # Renderer for user message activities
  #
  # Displays messages posted by users with customized title format
  class Message < BaseMessage
    # Override the default to show user information
    #
    # @return [String] HTML-safe string with user's name and UID
    def created_by_user_html
      return UNKNOWN_USER unless @work_activity.created_by_user

      user = @work_activity.created_by_user
      "#{user.given_name_safe} (@#{user.uid})"
    end

    # Override the title format for messages
    #
    # @return [String] HTML title with custom format
    def title_html
      "<span class='activity-history-title'>#{created_by_user_html} at #{created_updated_html}</span>"
    end
  end
end
