# frozen_string_literal: true

# Connect with the curators of a work when an activity occurs
#
class WorkStateTransitionNotification
  attr_reader :group_administrators, :depositor, :to_state, :from_state, :group,
                :work_url, :notification, :users, :id, :current_user_id, :work_title

  def initialize(work, current_user_id)
    @to_state = work.aasm.to_state
    @from_state = work.aasm.from_state
    @depositor = work.created_by_user
    @group = work.group
    @group_administrators = group.administrators.to_a
    @work_url = data_commons_url(work)

    # Troubleshooting https://github.com/pulibrary/pdc_describe/issues/1783
    if @work_url.include?("/describe/describe/")
      Rails.logger.error("URL #{@work_url} included /describe/describe/ and was fixed. See https://github.com/pulibrary/pdc_describe/issues/1783")
      @work_url = @work_url.gsub("/describe/describe/", "/describe/")
    end

    @work_title = work.title
    @id = work.id

    raise(NotImplementedError, "Invalid user ID provided.") if current_user_id.nil?
    @current_user_id = current_user_id
  end

  def send
    class_for_transition.add_work_activity(id, current_user_id)
  end

    private

      # rubocop:disable Metrics/MethodLength
      # I want the factory to be all in one method
      def class_for_transition
        case to_state
        when :awaiting_approval
          WorkStateTransition::AwaitingApproval
        when :approved
          WorkStateTransition::Approved
        when :draft
          case from_state
          when :none
            WorkStateTransition::NewSubmission
          when :awaiting_approval
            WorkStateTransition::ReturnedToDraft
          when :withdrawn
            WorkStateTransition::Resubmission
          end
        when :withdrawn
          WorkStateTransition::Withdrawn
        when :deletion_marker
          WorkStateTransition::DeletionMarker
        end
      end
      # rubocop:enable Metrics/MethodLength

      # Make sure we use the official "datacommons" URL for production (and not pdc-describe-prod)
      def data_commons_url(work)
        url = if Rails.env.production?
                path = Rails.application.routes.url_helpers.work_path(work)
                "https://datacommons.princeton.edu#{path}"
              else
                Rails.application.routes.url_helpers.work_url(work)
              end
        url
      end
end
