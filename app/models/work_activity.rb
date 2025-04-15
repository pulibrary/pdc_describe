# frozen_string_literal: true

require_relative "../lib/diff_tools"

# rubocop:disable Metrics/ClassLength
class WorkActivity < ApplicationRecord
  MESSAGE = "COMMENT" # TODO: Migrate existing records to "MESSAGE"; then close #825.
  NOTIFICATION = "NOTIFICATION"
  MESSAGE_ACTIVITY_TYPES = [MESSAGE, NOTIFICATION].freeze

  CHANGES = "CHANGES"
  DATACITE_ERROR = "DATACITE-ERROR"
  FILE_CHANGES = "FILE-CHANGES"
  MIGRATION_START = "MIGRATION_START"
  MIGRATION_COMPLETE = "MIGRATION_COMPLETE"
  PROVENANCE_NOTES = "PROVENANCE-NOTES"
  SYSTEM = "SYSTEM"
  EMBARGO = "EMBARGO"
  CHANGE_LOG_ACTIVITY_TYPES = [CHANGES, FILE_CHANGES, PROVENANCE_NOTES, SYSTEM, DATACITE_ERROR, MIGRATION_COMPLETE, EMBARGO].freeze

  USER_REFERENCE = /@[\w]*/ # e.g. @xy123

  include Rails.application.routes.url_helpers

  belongs_to :work
  has_many :work_activity_notifications, dependent: :destroy

  def self.add_work_activity(work_id, message, user_id, activity_type:, created_at: nil)
    activity = WorkActivity.new(
      work_id:,
      activity_type:,
      message:,
      created_by_user_id: user_id,
      created_at: # If nil, will be set by activerecord at save.
    )
    activity.save!
    activity.notify_users
    if activity_type == MESSAGE
      activity.notify_creator
    end

    activity
  end

  def self.activities_for_work(work_id, activity_types)
    where(work_id:, activity_type: activity_types)
  end

  def self.messages_for_work(work_id)
    activities_for_work(work_id, MESSAGE_ACTIVITY_TYPES)
  end

  def self.changes_for_work(work_id)
    activities_for_work(work_id, CHANGE_LOG_ACTIVITY_TYPES)
  end

  # notify the creator of the work whenever a message activity type is created
  def notify_creator
    # Don't notify the creator if they are already referenced in the message
    users_referenced.each do |uid|
      user_id = User.where(uid:).first&.id
      if user_id.nil?
        Rails.logger.info("Message #{id} for work #{work_id} referenced an non-existing user: #{uid}")
      elsif user_id == work.created_by_user_id
        Rails.logger.info("Skipping notification for creator #{work.created_by_user_id} of work #{work_id} because they are already referenced in the message")
      else
        WorkActivityNotification.create(work_activity_id: id, user_id: work.created_by_user_id)
      end
    end
    # If no users are referenced in the message, notify the creator
    if users_referenced.empty?
      WorkActivityNotification.create(work_activity_id: id, user_id: work.created_by_user_id)
    end
  end

  # Log notifications for each of the users references on the activity
  def notify_users
    users_referenced.each do |uid|
      user_id = User.where(uid:).first&.id
      if user_id.nil?
        notify_group(uid)
      else
        WorkActivityNotification.create(work_activity_id: id, user_id:)
      end
    end
  end

  def notify_group(groupid)
    group = Group.where(code: groupid).first
    if group.nil?
      Rails.logger.info("Message #{id} for work #{work_id} referenced an non-existing user: #{groupid}")
    else
      group.administrators.each do |admin|
        WorkActivityNotification.create(work_activity_id: id, user_id: admin.id)
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

  def renderer
    @renderer ||= begin
                    klass = if activity_type == CHANGES
                              MetadataChanges
                            elsif activity_type == FILE_CHANGES
                              FileChanges
                            elsif activity_type == MIGRATION_COMPLETE
                              Migration
                            elsif activity_type == PROVENANCE_NOTES
                              ProvenanceNote
                            elsif activity_type == EMBARGO
                              EmbargoEvent
                            elsif CHANGE_LOG_ACTIVITY_TYPES.include?(activity_type)
                              OtherLogEvent
                            else
                              Message
                            end
                    klass.new(self)

                  end
  end

  delegate :to_html, to: :renderer

  class Renderer
    def initialize(work_activity)
      @work_activity = work_activity
    end

    UNKNOWN_USER = "Unknown user outside the system"
    DATE_TIME_FORMAT = "%B %d, %Y %H:%M"
    DATE_FORMAT = "%B %d, %Y"
    SORTABLE_DATE_TIME_FORMAT = "%Y-%m-%d %H:%M"

    def to_html
      title_html + "<span class='message-html'>#{body_html.chomp}</span>"
    end

    def created_by_user_html
      return UNKNOWN_USER unless @work_activity.created_by_user

      "#{@work_activity.created_by_user.given_name_safe} (@#{@work_activity.created_by_user.uid})"
    end

    def created_sortable_html
      @work_activity.created_at.time.strftime(SORTABLE_DATE_TIME_FORMAT)
    end

    def created_updated_html
      created = @work_activity.created_at.time.strftime(DATE_TIME_FORMAT)
      updated = @work_activity.updated_at.time.strftime(DATE_TIME_FORMAT)
      created_date = @work_activity.created_at.time.strftime(DATE_FORMAT)
      updated_date = @work_activity.updated_at.time.strftime(DATE_FORMAT)
      if created_date == updated_date
        created
      else
        "#{created} (backdated event created #{updated})"
      end
    end

    def title_html
      "<span class='activity-history-title'>#{created_updated_html} by #{created_by_user_html}</span>"
    end
  end

  class MetadataChanges < Renderer
    # Returns the message formatted to display _metadata_ changes that were logged as an activity
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

  class Migration < Renderer
    # Returns the message formatted to display _file_ changes that were logged as an activity
    def body_html
      changes = JSON.parse(@work_activity.message)
      "<p>#{changes['message']}</p>"
    end
  end

  class BaseMessage < Renderer
    def body_html
      text = user_refernces(@work_activity.message)
      mark_down_to_html(text)
    end

    def mark_down_to_html(text_in)
      # allow ``` for code blocks (Kramdown only supports ~~~)
      text = text_in.gsub("```", "~~~")
      Kramdown::Document.new(text).to_html
    end

    def user_refernces(text_in)
      # convert user references to user links
      text_in.gsub(USER_REFERENCE) do |at_uid|
        uid = at_uid[1..-1]

        if uid
          group = Group.find_by(code: uid)
          if group
            "<a class='message-user-link' title='#{group.title}' href='#{@work_activity.group_path(group)}'>#{group.title}</a>"
          else
            user = User.find_by(uid:)
            user_info = if user
                          user.given_name_safe
                        else
                          uid
                        end
            "<a class='message-user-link' title='#{user_info}' href='#{@work_activity.users_path}/#{uid}'>#{at_uid}</a>"
          end
        else
          Rails.logger.warn("Failed to extract the user ID from #{uid}")
          UNKNOWN_USER
        end
      end
    end
  end

  class OtherLogEvent < BaseMessage
  end

  class EmbargoEvent < BaseMessage
    def created_by_user_html
      "the system"
    end
  end

  class Message < BaseMessage
    # Override the default:
    def created_by_user_html
      return UNKNOWN_USER unless @work_activity.created_by_user

      user = @work_activity.created_by_user
      "#{user.given_name_safe} (@#{user.uid})"
    end

    def title_html
      "<span class='activity-history-title'>#{created_by_user_html} at #{created_updated_html}</span>"
    end
  end

  class ProvenanceNote < BaseMessage
    def body_html
      message_hash = JSON.parse(@work_activity.message)
      text = user_refernces(message_hash["note"])
      message = mark_down_to_html(text)
      change_label = message_hash["change_label"]&.titleize
      change_label ||= "Change"
      # TODO: Make this show the change label with the note under see changes
      "<details class='message-html'><summary class='show-changes'>#{change_label}</summary>#{message}</details>"
    end
  end
end
# rubocop:enable Metrics/ClassLength
