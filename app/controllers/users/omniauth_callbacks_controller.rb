# frozen_string_literal: true

class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def cas
    @user = User.from_cas(request.env["omniauth.auth"])
    if @user.nil?
      redirect_to root_path
      flash[:notice] = "You are not authorized"
    else
      sign_in_and_redirect @user, event: :authentication # this will throw if @user is not activated
      if is_navigational_format?
        set_flash_message(:notice, :success, kind: "from Princeton Central Authentication Service")
      end
    end
  end

  def entra_id
    @user = User.from_entra(request.env["omniauth.auth"])
    if @user.nil?
      redirect_to root_path
      flash[:notice] = "You are not authorized"
    else
      sign_in_and_redirect @user, event: :authentication # this will throw if @user is not activated
      if is_navigational_format?
        set_flash_message(:notice, :success, kind: "from Entra ID")
      end
    end
  end

  def failure
    notify_entra_login_failure
    super
  end

  private

    def notify_entra_login_failure
      return unless failed_strategy&.name == "entra_id"

      Honeybadger.notify(
        "Entra ID login failed: #{failure_message}",
        context: {
          provider: "entra_id",
          error_type: omniauth_error_type,
          error: omniauth_error_message
        }
      )
    end

    def omniauth_error_type
      header("omniauth.error.type")
    end

    def omniauth_error_message
      exception = header("omniauth.error")
      exception.message if exception.respond_to?(:message)
    end

    def header(key)
      request.respond_to?(:get_header) ? request.get_header(key) : request.env[key]
    end
end
