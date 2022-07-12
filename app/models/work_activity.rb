# frozen_string_literal: true

class WorkActivity < ApplicationRecord
  belongs_to :work

  USER_REFERENCE = /@[\w]*/.freeze  # e.g. @xy123

  def self.add_system_activity(work_id, message, user_id, activity_type: "SYSTEM")
    activity = WorkActivity.new(
      work_id: work_id,
      activity_type: activity_type,
      message: message,
      created_by_user_id: user_id
    )
    activity.save!

    activity.users_referenced.each do |uid|
      user_id = User.where(uid: uid).first&.id
      if user_id.nil?
        Rails.logger.info("Message #{activity.id} for work #{work_id} referenced an non-existing user: #{uid}")
      else
        WorkActivityNotification.create(work_activity_id: activity.id, user_id: user_id)
      end
    end

    activity
  end

  def users_referenced
    message.scan(USER_REFERENCE).map { |netid| netid[1..-1] }
  end

  def created_by_user
    return nil if created_by_user_id.nil?
    User.find(created_by_user_id)
  end

  def message_html
    message_with_links = message.gsub(USER_REFERENCE) do |at_uid|
      uid = at_uid[1..-1]
      "<a class='comment-user-link' href='/users/#{uid}'>#{at_uid}</a>"
    end
    Kramdown::Document.new(message_with_links).to_html
  end
end
