# frozen_string_literal: true
class ApplicationController < ActionController::Base
  # This is necessary only for localhost development, with storage configured for the filesystem,
  # but it shouldn't cause problems in other environments that use S3.
  # Including this concern lets the disk service generate URLs using
  # the same host, protocol, and port as the current request.
  include ActiveStorage::SetCurrent

  protect_from_forgery with: :exception
  before_action :authenticate_user!

  def new_session_path(_scope)
    new_user_session_path
  end

  # See https://github.com/rails/rails/issues/42243#issuecomment-913912639
  # and https://github.com/rails/rails/issues/42243#issuecomment-1182336847
  def url_options
    super.except(:script_name)
  end

  private

    # Take all the errors from the exception and the work and combine them into a single error message that can be shown to the user
    #
    # @param [AASM::InvalidTransition] aasm_error Error thrown by trying to transition states
    # @param [Work] work The work that had the issue
    #
    # @return [String] a combined error message for the work and transition error
    #
    def message_from_aasm_error(aasm_error:, work:)
      message = aasm_error.message
      if work.errors.count > 0
        message = work.errors.to_a.join(", ")
      end
      message.chop! if message.last == "."
      message
    end

    # Validates that the current user can modify the work
    #
    # @params [Work] work the work to be modifed
    # @params [String] uneditable_message message to send to honey bandger about the work not being editable by the user
    # @params [String] current_state_message message to send to honey bandger about the work not being editable in the current state
    #
    # @returns false if an error occured
    #
    def validate_modification_permissions(work:, uneditable_message:, current_state_message:)
      no_error = false
      if current_user.blank? || !work.editable_by?(current_user)
        Honeybadger.notify(uneditable_message)
        redirect_to root_path, notice: I18n.t("works.uneditable.privs")
      elsif !work.editable_in_current_state?(current_user)
        Honeybadger.notify(current_state_message)
        redirect_to root_path, notice: I18n.t("works.uneditable.approved")
      else
        no_error = true
      end

      no_error
    end

    # returns either the group sent in by the user in group_id
    #   OR the default group for the user
    #
    def params_group_id
      # Do not allow a nil for the group id
      @params_group_id ||= begin
        group_id = params[:group_id]
        if group_id.blank?
          group_id = current_user.default_group.id
          Honeybadger.notify("We got a nil group as part of the parameters #{params} #{request}")
        end
        group_id
      end
    end

    # parses the embargo date from the parameters and parses into a Date object
    def embargo_date
      embargo_date_param = params["embargo-date"]
      return nil if embargo_date_param.blank?

      Date.parse(embargo_date_param)
    rescue Date::Error
      message = "Failed to parse the embargo date #{embargo_date_param} for Work #{@work.id}"
      Rails.logger.error(message)
      Honeybadger.notify(message)
      nil
    end

    # parameters utilize to update the work converted from the user's parameters
    def update_params
      {
        group_id: params_group_id,
        embargo_date:,
        resource: FormToResourceService.convert(params, @work)
      }
    end

    def prepare_decorators_for_work_form(work)
      @work_decorator = WorkDecorator.new(work, current_user)
      @form_resource_decorator = FormResourceDecorator.new(work, current_user)
    end

    def rescue_aasm_error
      yield
    rescue AASM::InvalidTransition => error
      message = message_from_aasm_error(aasm_error: error, work: @work)

      Honeybadger.notify("Invalid #{@work.current_transition}: #{error.message} errors: #{message}")
      transition_error_message = "We apologize, the following errors were encountered: #{message}. Please contact the PDC Describe administrators for any assistance."
      @errors = [transition_error_message]

      redirect_aasm_error(transition_error_message)
    end
end
