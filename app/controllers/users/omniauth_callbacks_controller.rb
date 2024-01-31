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
        if @user.default_group_id == Group.plasma_laboratory.id
          set_flash_message(:notice, :success, kind: "from Princeton Central Authentication Service")
        else
          flash[:notice] = "You are not a PPPL user."
        end
      end
    end
  end
end
