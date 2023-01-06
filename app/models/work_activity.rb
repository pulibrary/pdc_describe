# frozen_string_literal: true

require_relative "../lib/diff_tools"

# rubocop:disable Metrics/ClassLength
class WorkActivity < ApplicationRecord
  CHANGES = "CHANGES"
  COMMENT = "COMMENT"
  FILE_CHANGES = "FILE-CHANGES"
  SYSTEM = "SYSTEM"
  USER_REFERENCE = /@[\w]*/.freeze # e.g. @xy123

  include Rails.application.routes.url_helpers

  belongs_to :work
  has_many :work_activity_notifications, dependent: :destroy

  def self.add_system_activity(work_id, message, user_id, activity_type: "SYSTEM")
    activity = WorkActivity.new(
      work_id: work_id,
      activity_type: activity_type,
      message: message,
      created_by_user_id: user_id
    )
    activity.save!
    activity.notify_users
    activity
  end

  # Log notifications for each of the users references on the activity
  def notify_users
    users_referenced.each do |uid|
      user_id = User.where(uid: uid).first&.id
      if user_id.nil?
        Rails.logger.info("Message #{id} for work #{work_id} referenced an non-existing user: #{uid}")
      else
        WorkActivityNotification.create(work_activity_id: id, user_id: user_id)
      end
    end
  end

  # Returns the `uid` of the users referenced on the activity (without the `@` symbol)
  def users_referenced
    message.scan(USER_REFERENCE).map { |at_uid| at_uid[1..-1] }
  end

  def created_by_user
    return nil unless created_by_user_id

    User.find(created_by_user_id)
  end

  def self.unknown_user
    "Unknown user outside the system"
  end

  def comment_event_type?
    activity_type == COMMENT
  end

  def changes_event_type?
    activity_type == CHANGES
  end

  def file_changes_event_type?
    activity_type == FILE_CHANGES
  end

  def system_event_type?
    activity_type == SYSTEM
  end

  def log_event_type?
    system_event_type? || file_changes_event_type? || changes_event_type?
  end

  def event_type
    if comment_event_type?
      "comment"
    else
      "log"
    end
  end

  def to_html
    if changes_event_type?
      metadata_changes_html
    elsif file_changes_event_type?
      file_changes_html
    else
      comment_html
    end
  end
  alias message_html to_html

  private

    def created_at_time
      created_at.time
    end

    def event_timestamp
      created_at_time.strftime("%B %d, %Y %H:%M")
    end

    def event_timestamp_html
      "#{event_timestamp} by " if system_event_type? || log_event_type?
    end

    # This is working
    def comment_timestamp_html
      "at #{event_timestamp}" if comment_event_type?
    end

    def title_html
      <<-HTML
<span class="activity-history-title">
  #{event_timestamp_html}
  #{created_by_user_html}
  #{comment_timestamp_html}
</span>
      HTML
    end

    def event_html(children:)
      title_html + "<span class='comment-html'>#{children.chomp}</span>"
    end

    # Returns the message formatted to display _file_ changes that were logged as an activity
    def file_changes_html
      changes = JSON.parse(message)
      changes_html = changes.map do |change|
        icon = if change["action"] == "deleted"
                 '<i class="bi bi-file-earmark-minus-fill file-deleted-icon"></i>'
               else
                 '<i class="bi bi-file-earmark-plus-fill file-added-icon"></i>'
               end
        "<tr><td>#{icon}</td><td>#{change['action']}</td> <td>#{change['filename']}</td>"
      end

      children = "<p><b>Files updated:</b></p><table>#{changes_html.join}</table>"
      event_html(children: children)
    end

    # Returns the message formatted to display _metadata_ changes that were logged as an activity
    def metadata_changes_html
      html = title_html
      changes = JSON.parse(message)

      changes.keys.each do |field|
        change = changes[field]
        mapped = change.map { |value| change_value_html(value) }
        values = mapped.join
        html += "<details class='comment-html'><summary class='show-changes'>#{field}</summary>#{values}</details>"
      end

      html
    end

    # rubocop:disable Metrics/MethodLength
    def comment_html
      # convert user references to user links
      text = message.gsub(USER_REFERENCE) do |at_uid|
        uid = at_uid[1..-1]
        user_info = self.class.unknown_user

        if uid
          user = User.find_by(uid: uid)
          user_info = if user
                        user.display_name_safe
                      else
                        uid
                      end
        end

        "<a class='comment-user-link' title='#{user_info}' href='#{users_path}/#{uid}'>#{at_uid}</a>"
      end

      # allow ``` for code blocks (Kramdown only supports ~~~)
      text = text.gsub("```", "~~~")
      parsed_document = Kramdown::Document.new(text)
      children = parsed_document.to_html

      event_html(children: children)
    end
    # rubocop:enable Metrics/MethodLength

    def created_by_user_html
      return self.class.unknown_user unless created_by_user

      created_by_user.display_name_safe
    end

    def created_at_html
      return unless created_at

      created_at_time = created_at.time
      created_at_time.strftime("%B %d, %Y %H:%M")
    end

    def change_value_html(value)
      if value["action"] == "changed"
        DiffTools::SimpleDiff.new(value["from"], value["to"]).to_html
      else
        "old change"
      end
    end
end
# rubocop:enable Metrics/ClassLength
