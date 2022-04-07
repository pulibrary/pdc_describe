# frozen_string_literal: true
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  before_action :authenticate_user!

  def new_session_path(_scope)
    new_user_session_path
  end

  # Take a newly signed in user to their own User page after sign in
  def after_sign_in_path_for(user)
    user_path(user)
  end
end
