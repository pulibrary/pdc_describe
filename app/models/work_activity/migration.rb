# frozen_string_literal: true

class WorkActivity
  # Renderer for migration completion activities
  #
  # Displays migration completion messages
  class Migration < Renderer
    # Returns the message formatted to display migration completion
    #
    # @return [String] HTML paragraph with migration message
    def body_html
      changes = JSON.parse(@work_activity.message)
      "<p>#{changes['message']}</p>"
    end
  end
end
