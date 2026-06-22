# frozen_string_literal: true

require_relative "../../lib/diff_tools"

class WorkActivity
  # Renderer for metadata change activities
  #
  # Displays field-by-field changes with expandable details and diffs
  class MetadataChanges < Renderer
    # Returns the message formatted to display metadata changes that were logged as an activity
    #
    # @return [String] HTML representation of metadata changes
    def body_html
      message_json = JSON.parse(@work_activity.message)

      # Messages should consistently be Arrays of Hashes, but this might require a migration from legacy field records
      messages = if message_json.is_a?(Array)
                   message_json
                 else
                   Array.wrap(message_json)
                 end

      elements = messages.map do |message|
        markup = if message.is_a?(Hash)
                   message.keys.map do |field|
                     mapped = message[field].map { |value| change_value_html(value) }
                     "<details class='message-html'><summary class='show-changes'>#{field&.titleize}</summary>#{mapped.join}</details>"
                   end
                 else
                   # For handling cases where WorkActivity#message only contains Strings, or Arrays of Strings
                   [
                     "<details class='message-html'><summary class='show-changes'></summary>#{message}</details>"
                   ]
                 end
        markup.join
      end

      elements.flatten.join
    end

    private

      # Renders the HTML for a single change value
      #
      # @param value [Hash] Change value with 'action', 'from', and 'to' keys
      # @return [String] HTML representation of the change
      def change_value_html(value)
        if value["action"] == "changed"
          DiffTools::SimpleDiff.new(value["from"], value["to"]).to_html
        else
          "old change"
        end
      end
  end
end
