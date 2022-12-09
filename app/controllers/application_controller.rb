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
end
