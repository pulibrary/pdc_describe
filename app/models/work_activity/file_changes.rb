# frozen_string_literal: true

class WorkActivity
  # Renderer for file change activities
  #
  # Displays summary of file operations (additions, deletions, replacements)
  class FileChanges < Renderer
    # Returns the message formatted to display file changes that were logged as an activity
    #
    # @return [String] HTML table summarizing file changes
    def body_html
      changes = JSON.parse(@work_activity.message)
      if changes.is_a?(Hash)
        changes = [changes]
      end

      files_added = changes.select { |v| v["action"] == "added" }
      files_deleted = changes.select { |v| v["action"] == "removed" }
      files_replaced = changes.select { |v| v["action"] == "replaced" }

      changes_html = []
      unless files_added.empty?
        label = "Files Added: "
        label += files_added.length.to_s
        changes_html << "<tr><td>#{label}</td></tr>"
      end

      unless files_deleted.empty?
        label = "Files Deleted: "
        label += files_deleted.length.to_s
        changes_html << "<tr><td>#{label}</td></tr>"
      end

      unless files_replaced.empty?
        label = "Files Replaced: "
        label += files_replaced.length.to_s
        changes_html << "<tr><td>#{label}</td></tr>"
      end

      "<table>#{changes_html.join}</table>"
    end
  end
end
