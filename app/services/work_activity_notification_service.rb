# frozen_string_literal: true

# Service for managing WorkActivity notifications
#
# Handles creating notifications for users mentioned in activities,
# as well as automatic notifications to work creators and curators.
class WorkActivityNotificationService
  USER_REFERENCE = /@[\w]*/ # e.g. @xy123

  # @param work_activity [WorkActivity] The work activity to process notifications for
  def initialize(work_activity)
    @work_activity = work_activity
  end

  # Creates notifications for curator if assigned
  #
  # Sends a notification to the curator unless they are already referenced in the message
  #
  # @return [void]
  def notify_curator
    # do not send a notification if no curator is assigned
    return if @work_activity.work.curator_user_id.nil?

    # only send a notification to the curator if they are not already referenced in the message
    if WorkActivityNotification.where(work_activity_id: @work_activity.id, user_id: @work_activity.work.curator_user_id).count.zero?
      WorkActivityNotification.create(work_activity_id: @work_activity.id, user_id: @work_activity.work.curator_user_id)
    end
  end

  # Creates notification for the work creator
  #
  # Sends a notification to the creator unless they are already referenced in the message
  #
  # @return [void]
  def notify_creator
    # only send a notification to the creator if they are not already referenced in the message
    if WorkActivityNotification.where(work_activity_id: @work_activity.id, user_id: @work_activity.work.created_by_user_id).count.zero?
      WorkActivityNotification.create(work_activity_id: @work_activity.id, user_id: @work_activity.work.created_by_user_id)
    end
  end

  # Creates notifications for all users and groups referenced in the activity
  #
  # Parses @mentions in the message and creates notifications for each referenced user or group
  #
  # @return [void]
  def notify_users
    users_referenced.each do |uid|
      user_id = User.where(uid:).first&.id
      if user_id.nil?
        notify_group(uid)
      else
        WorkActivityNotification.create(work_activity_id: @work_activity.id, user_id:)
      end
    end
  end

  # Creates notifications for all administrators of a group
  #
  # @param groupid [String] The group code/identifier
  # @return [void]
  def notify_group(groupid)
    group = Group.where(code: groupid).first
    if group.nil?
      Rails.logger.info("Message #{@work_activity.id} for work #{@work_activity.work_id} referenced an non-existing user: #{groupid}")
    else
      group.administrators.each do |admin|
        WorkActivityNotification.create(work_activity_id: @work_activity.id, user_id: admin.id)
      end
    end
  end

  # Extracts user UIDs from @mentions in the message
  #
  # @return [Array<String>] Array of user UIDs (without the @ symbol)
  def users_referenced
    @work_activity.message.scan(USER_REFERENCE).map { |at_uid| at_uid[1..-1] }
  end
end
