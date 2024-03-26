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

  # Take all the errors from the exception and the work and combine them into a single error message that can be shown to the user
  #
  # @param [AASM::InvalidTransition] aasm_error Error thrown by trying to transition states
  # @param [Work] work The work that had the issue
  #
  # @return [String] a combined error message for the work and transition error
  #
  def message_from_assm_error(aasm_error:, work:)
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
end
