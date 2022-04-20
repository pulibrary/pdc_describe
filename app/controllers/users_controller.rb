# frozen_string_literal: true
class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update]

  # GET /users/1 or /users/1.json
  def show
    @can_edit = can_edit?
    if current_user.id == @user.id
      @my_datasets = Dataset.my_datasets(current_user)
      @awaiting_datasets = Dataset.admin_awaiting_datasets(current_user)
      @withdrawn_datasets = Dataset.admin_withdrawn_datasets(current_user)
      render "dashboard"
    else
      @datasets = Dataset.my_datasets(@user)
      render "show"
    end
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
  def update
    if can_edit?
      respond_to do |format|
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
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def user_params
      params.require(:user).permit([:display_name, :full_name, :orcid])
    end

    def can_edit?
      return true if current_user.id == @user.id
      current_user.superadmin?
    end
end
