# frozen_string_literal: true

class WorkActivity < ApplicationRecord
  belongs_to :work

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
      changes_html
    else
      comment_html
    end
  end

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
    Kramdown::Document.new(text).to_html
  end

  def changes_html
    text = ""
    json = JSON.parse(message)
    json.keys.each do |key|
      if json[key].is_a?(Array)
        text += "<p><b>#{key}</b>:"
        json[key].each do |value|
          if value["action"] == "added"
            text += <<-HTML
              <i>(added)</i> <span>#{value["value"]}</span>
            HTML
          elsif value["action"] == "removed"
            text += <<-HTML
              <i>(removed)</i> <span>#{value["value"]}</span>
            HTML
          else
            text += <<-HTML
              <span style="text-decoration: line-through;">#{value["from"]}</span>
              <span>#{value["to"]}</span>
            HTML
          end
        end
        text += "</p>"
      else
        value = json[key]
        text += <<-HTML
          <p><b>#{key}</b>:
            <span style="text-decoration: line-through;">#{value["from"]}</span>
            <span>#{value["to"]}</span>
          </p>
        HTML
      end
    end
    text
  end
end
