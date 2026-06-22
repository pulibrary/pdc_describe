# frozen_string_literal: true

class WorkActivity
  # Renderer for provenance note activities
  #
  # Displays provenance notes with expandable change labels
  class ProvenanceNote < BaseMessage
    # Renders provenance note with change label
    #
    # @return [String] HTML with expandable details showing the note
    def body_html
      message_hash = JSON.parse(@work_activity.message)
      text = user_references(message_hash["note"])
      message = mark_down_to_html(text)
      change_label = message_hash["change_label"]&.titleize
      change_label ||= "Change"
      # TODO: Make this show the change label with the note under see changes
      "<details class='message-html'><summary class='show-changes'>#{change_label}</summary>#{message}</details>"
    end
  end
end
