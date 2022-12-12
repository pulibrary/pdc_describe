# frozen_string_literal: true

require_relative "../lib/diff"

class WorkActivity < ApplicationRecord
  belongs_to :work

  has_many :work_activity_notifications, dependent: :destroy

  USER_REFERENCE = /@[\w]*/.freeze # e.g. @xy123

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
    return nil if created_by_user_id.nil?
    User.find(created_by_user_id)
  end

  def message_html
    if activity_type == "CHANGES"
      metadata_changes_html
    elsif activity_type == "FILE-CHANGES"
      file_changes_html
    else
      comment_html
    end
  end

  private

    def comment_html
      # convert user references to user links
      text = message.gsub(USER_REFERENCE) do |at_uid|
        uid = at_uid[1..-1]
        user = User.where(uid: uid).first
        user_info = user&.display_name_safe || uid
        "<a class='comment-user-link' title='#{user_info}' href='{USER-PATH-PLACEHOLDER}/#{uid}'>#{at_uid}</a>"
      end
      # allow ``` for code blocks (Kramdown only supports ~~~)
      text = text.gsub("```", "~~~")
      parsed_document = Kramdown::Document.new(text)
      parsed_document.to_html
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
      "<p><b>Files updated:</b></p><table>#{changes_html.join}</table>"
    end

    # Returns the message formatted to display _metadata_ changes that were logged as an activity
    def metadata_changes_html
      text = ""
      changes = JSON.parse(message)
      changes.keys.each do |field|
        values = changes[field].map { |value| change_value_html(value) }.join
        text += "<p><b>#{field}</b>: #{values}</p>"
      end
      text
    end

    def change_value_html(value)
      if value["action"] == "changed"
        SimpleDiff.new(value["from"], value["to"]).to_html
      else
        "old change"
      end
    end
end
