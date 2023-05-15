# frozen_string_literal: true
class GroupsController < ApplicationController
  def index; end

  def show
    @group = Group.find(params[:id])
    @can_edit = can_edit?
  end

  def edit
    @group = Group.find(params[:id])
    if can_edit?
      render "edit"
    else
      Rails.logger.warn("Unauthorized to edit group #{@group.id} (current user: #{current_user.id})")
      redirect_to groups_path
    end
  end

  # rubocop:disable Metrics/MethodLength
  def update
    @group = Group.find(params[:id])
    if can_edit?
      respond_to do |format|
        if @group.update(group_params)
          format.html { redirect_to group_url(@group), notice: "Group was successfully updated." }
          format.json { render :show, status: :ok, location: @group }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @group.errors, status: :unprocessable_entity }
        end
      end
    else
      Rails.logger.warn("Unauthorized to update group #{@group.id} (current user: #{current_user.id})")
      redirect_to groups_path
    end
  end
  # rubocop:enable Metrics/MethodLength

  # This is a JSON only endpoint
  def add_admin
    @group = Group.find(params[:id])
    @group.add_administrator(current_user, User.new_for_uid(params[:uid]))
    check_and_render
  end

  # This is a JSON only endpoint
  def add_submitter
    @group = Group.find(params[:id])
    @group.add_submitter(current_user, User.new_for_uid(params[:uid]))
    check_and_render
  end

  # This is a JSON only endpoint
  def delete_user_from_group
    @group = Group.find(params[:id])
    @group.delete_permission(current_user, User.find_by(uid: params[:uid]))
    check_and_render
  end

  private

    def check_and_render
      if @group.errors.count > 0 && @group.errors.first.message == "Unauthorized"
        render status: :unauthorized, json: { message: "Unauthorized" }
      elsif @group.errors.count > 0
        render status: :bad_request, json: { message: @group.errors.first.message }
      else
        render status: :ok, json: { message: "OK" }
      end
    end

    # Only allow trusted parameters through.
    def group_params
      params.require(:group).permit([:title, :description])
    end

    def can_edit?
      current_user.can_admin? @group
    end
end
