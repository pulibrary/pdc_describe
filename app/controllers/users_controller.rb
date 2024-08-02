# frozen_string_literal: true
class UsersController < ApplicationController
  # Constants set by the <form> <input> parameters transmitted using POST/PATCH/PUT requests
  GROUP_MESSAGING_DISABLED = "0"
  GROUP_MESSAGING_ENABLED = "1"

  # Notice that `set_user` sets the value of the user that we are viewing or editing
  # while `authenticate_user` sets the value of the current logged in user.
  # These values can be different (e.g. when an admin users is editing the information
  # of another user)
  before_action :set_user, only: %i[show edit update]
  before_action :authenticate_user!

  def index
    @users = User.all.sort_by { |user| user.family_name || "" }
  end

  # GET /users/1
  def show
    @search_terms = params["q"].presence
    @can_edit = can_edit?
    @my_dashboard = current_user.id == @user.id
    render "forbidden", status: :forbidden if !current_user.super_admin? && !@my_dashboard

    @unfinished_works = WorkList.unfinished_works(@user, @search_terms)
    @completed_works = WorkList.completed_works(@user, @search_terms)
    @withdrawn_works = WorkList.withdrawn_works(@user, @search_terms)
    @works_found = @unfinished_works.length + @completed_works.length + @withdrawn_works.length
  end

  # GET /users/1/edit
  def edit
    unless can_edit?
      Rails.logger.warn("Unauthorized to edit user #{@user.id} (current user: #{current_user.id})")
      redirect_to user_path(@user)
    end
  end

  # PATCH/PUT /users/1 or /users/1.json
  def update
    if can_edit?
      respond_to do |format|
        update_groups_with_messaging if user_params.key?(:groups_with_messaging)

        if @user.update(user_params)
          format.html { redirect_to user_url(@user), notice: "User was successfully updated." }
          format.json { render :show, status: :ok, location: @user }
        else
          # return 200 so the loadbalancer doesn't capture the error
          format.html { render :edit }
          format.json { render json: @user.errors }
        end
      end
    else
      Rails.logger.warn("Unauthorized to update user #{@user.id} (current user: #{current_user.id})")
      redirect_to user_path(@user)
    end
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_user
      user_id = user_id_from_url
      @user = User.friendly.find(user_id)
      redirect_to action: action_name, id: @user.friendly_id, status: :moved_permanently unless @user.friendly_id == user_id
    end

    def user_id_from_url
      # For external users UID is in the form `user-name@gmail.com`, however, Rails eats the ".com" from
      # the UID and dumps it into the `format` param. Here we make sure the ".com" is preserved when the
      # UID looks to be an external user id.
      external_uid = params[:id].include?("@")
      if external_uid && params["format"] == "com"
        "#{params[:id]}.#{params['format']}"
      else
        params[:id]
      end
    end

    # Only allow a list of trusted parameters through.
    def user_params
      @user_params ||= params.require(:user).permit([:given_name, :full_name, :family_name, :orcid, :email_messages_enabled, groups_with_messaging: {}])
    end

    def can_edit?
      current_user.id == @user.id or current_user.super_admin?
    end

    def parameter_enables_messaging?(form_value)
      form_value.to_s == GROUP_MESSAGING_ENABLED
    end

    def update_groups_with_messaging
      if user_params.key?(:groups_with_messaging)
        extracted = user_params.extract!(:groups_with_messaging)
        groups_with_messaging = extracted[:groups_with_messaging]

        groups_with_messaging.each_pair do |id, param|
          group_id, subcommunity = id.split("_")
          selected_group = Group.find_by(id: group_id)

          if parameter_enables_messaging?(param)
            selected_group.enable_messages_for(user: @user, subcommunity:)
          else
            selected_group.disable_messages_for(user: @user, subcommunity:)
          end
        end
      end
    end
end
