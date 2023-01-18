# frozen_string_literal: true

require_relative "../lib/diff_tools"

# rubocop:disable Metrics/ClassLength
class WorkActivity < ApplicationRecord
  MESSAGE = "COMMENT" # TODO: Migrate existing records to "MESSAGE"; then close #825.
  NOTIFICATION = "NOTIFICATION"
  MESSAGE_ACTIVITY_TYPES = [MESSAGE, NOTIFICATION].freeze

  CHANGES = "CHANGES"
  FILE_CHANGES = "FILE-CHANGES"
  PROVENANCE_NOTES = "PROVENANCE-NOTES"
  SYSTEM = "SYSTEM"
  DATACITE_ERROR = "DATACITE-ERROR"
  CHANGE_LOG_ACTIVITY_TYPES = [CHANGES, FILE_CHANGES, PROVENANCE_NOTES, SYSTEM, DATACITE_ERROR].freeze

  USER_REFERENCE = /@[\w]*/.freeze # e.g. @xy123

  include Rails.application.routes.url_helpers

  belongs_to :work
  has_many :work_activity_notifications, dependent: :destroy

  def self.add_work_activity(work_id, message, user_id, activity_type:, date: nil)
    activity = WorkActivity.new(
      work_id: work_id,
      activity_type: activity_type,
      message: message,
      created_by_user_id: user_id,
      created_at: date # If nil, will be set by activerecord at save.
    )
    activity.save!
    activity.notify_users
    activity
  end

  def self.activities_for_work(work_id, types = [])
    context = where(work_id: work_id).order(updated_at: :desc)
    if types.count > 0
      context = context.where(activity_type: types)
    end
    context
  end

  def self.messages_for_work(work_id)
    activities_for_work(work_id, MESSAGE_ACTIVITY_TYPES)
  end

  def self.changes_for_work(work_id)
    activities_for_work(work_id, CHANGE_LOG_ACTIVITY_TYPES)
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

  def message_event_type?
    MESSAGE_ACTIVITY_TYPES.include? activity_type
  end

  def log_event_type?
    CHANGE_LOG_ACTIVITY_TYPES.include? activity_type
  end

  def to_html
    klass = if activity_type == CHANGES
       MetadataChanges
     elsif activity_type == FILE_CHANGES
       FileChanges
     elsif CHANGE_LOG_ACTIVITY_TYPES.include?(activity_type)
       OtherLogEvent
     else
       Message
     end
     renderer = klass.new(self)
     renderer.to_html
  end

  class Renderer
    def initialize(work_activity)
      @work_activity = work_activity
    end

    UNKNOWN_USER = "Unknown user outside the system"

    def to_html
      title_html + "<span class='message-html'>#{body_html.chomp}</span>"
    end

    def created_by_user_html
      return UNKNOWN_USER unless @work_activity.created_by_user

      @work_activity.created_by_user.display_name_safe
    end

    def created_at_html
      @work_activity.created_at.time.strftime("%B %d, %Y %H:%M")
    end

    def title_html
      "<span class='activity-history-title'>#{created_at_html} by #{created_by_user_html}</span>"
    end
  end

  class MetadataChanges < Renderer
    # Returns the message formatted to display _metadata_ changes that were logged as an activity
    def body_html
      changes = JSON.parse(@work_activity.message)

      changes.keys.map do |field|
        mapped = changes[field].map { |value| change_value_html(value) }
        "<details class='message-html'><summary class='show-changes'>#{field}</summary>#{mapped.join}</details>"
      end.join
    end

    def change_value_html(value)
      if value["action"] == "changed"
        DiffTools::SimpleDiff.new(value["from"], value["to"]).to_html
      else
        "old change"
      end
    end
  end

  class FileChanges < Renderer
    # Returns the message formatted to display _file_ changes that were logged as an activity
    def body_html
      changes = JSON.parse(@work_activity.message)
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
  end

  class BaseMessage < Renderer
    # rubocop:disable Metrics/MethodLength
    def body_html
      # convert user references to user links
      text = @work_activity.message.gsub(USER_REFERENCE) do |at_uid|
        uid = at_uid[1..-1]
        user_info = UNKNOWN_USER

        if uid
          user = User.find_by(uid: uid)
          user_info = if user
                        user.display_name_safe
                      else
                        uid
                      end
        end

        "<a class='message-user-link' title='#{user_info}' href='#{@work_activity.users_path}/#{uid}'>#{at_uid}</a>"
      end

      # allow ``` for code blocks (Kramdown only supports ~~~)
      text = text.gsub("```", "~~~")
      Kramdown::Document.new(text).to_html
    end
    # rubocop:enable Metrics/MethodLength
  end

  class OtherLogEvent < BaseMessage
  end

  class Message < BaseMessage
    # Override the default:
    def title_html
      "<span class='activity-history-title'>#{created_by_user_html} at #{created_at_html}</span>"
    end
  end
end
# rubocop:enable Metrics/ClassLength
