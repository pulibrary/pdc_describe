# frozen_string_literal: true
class UsersController < ApplicationController
  # Constants set by the <form> <input> parameters transmitted using POST/PATCH/PUT requests
  COLLECTION_MESSAGING_DISABLED = "0"
  COLLECTION_MESSAGING_ENABLED = "1"

  before_action :set_user, only: %i[show edit update]

  def index
    @users = User.all
  end

  # GET /users/1
  def show
    @can_edit = can_edit?
    @my_dashboard = current_user.id == @user.id
    @unfinished_works = Work.unfinished_works(@user)
    @completed_works = Work.completed_works(@user)
    @withdrawn_works = Work.withdrawn_works(@user)
    render "show"
  end

  # GET /users/1/edit
  def edit
    if can_edit?
      render "edit"
    else
      Rails.logger.warn("Unauthorized to edit user #{@user.id} (current user: #{current_user.id})")
      redirect_to user_path(@user)
    end
  end

  # PATCH/PUT /users/1 or /users/1.json
  # rubocop:disable Metrics/MethodLength
  def update
    if can_edit?
      respond_to do |format|
        update_collections_with_messaging if user_params.key?(:collections_with_messaging)

        if @user.update(user_params)
          format.html { redirect_to user_url(@user), notice: "User was successfully updated." }
          format.json { render :show, status: :ok, location: @user }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @user.errors, status: :unprocessable_entity }
        end
      end
    else
      Rails.logger.warn("Unauthorized to update user #{@user.id} (current user: #{current_user.id})")
      redirect_to user_path(@user)
    end
    # rubocop:enable Metrics/MethodLength
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.friendly.find(params[:id])
      redirect_to action: action_name, id: @user.friendly_id, status: :moved_permanently unless @user.friendly_id == params[:id]
    end

    # Only allow a list of trusted parameters through.
    def user_params
      @user_params ||= params.require(:user).permit([:display_name, :full_name, :family_name, :orcid, :email_messages_enabled, { collections_with_messaging: {} }])
    end

    def can_edit?
      return true if current_user.id == @user.id
      current_user.super_admin?
    end

    def parameter_enables_messaging?(form_value)
      form_value.to_s == COLLECTION_MESSAGING_ENABLED
    end

    def update_collections_with_messaging
      if user_params.key?(:collections_with_messaging)
        extracted = user_params.extract!(:collections_with_messaging)
        collections_with_messaging = extracted[:collections_with_messaging]

        collections_with_messaging.each_pair do |collection_id, param|
          selected_collection = Collection.find_by(id: collection_id)

          if parameter_enables_messaging?(param)
            @user.enable_messages_from(collection: selected_collection)
          else
            @user.disable_messages_from(collection: selected_collection)
          end
        end
      end
    end
end
