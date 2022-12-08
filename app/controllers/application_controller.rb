# frozen_string_literal: true
class ApplicationController < ActionController::Base
  include ActiveStorage::SetCurrent

  protect_from_forgery with: :exception
  before_action :authenticate_user!

  def new_session_path(_scope)
    new_user_session_path
  end
end
