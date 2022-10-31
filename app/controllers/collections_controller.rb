# frozen_string_literal: true
class CollectionsController < ApplicationController
  def index; end

  def show
    @collection = Collection.find(params[:id])
    @can_edit = can_edit?
  end

  def edit
    @collection = Collection.find(params[:id])
    if can_edit?
      render "edit"
    else
      Rails.logger.warn("Unauthorized to edit collection #{@collection.id} (current user: #{current_user.id})")
      redirect_to collections_path
    end
  end

  # rubocop:disable Metrics/MethodLength
  def update
    @collection = Collection.find(params[:id])
    if can_edit?
      respond_to do |format|
        if @collection.update(collection_params)
          format.html { redirect_to collection_url(@collection), notice: "Collection was successfully updated." }
          format.json { render :show, status: :ok, location: @collection }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: @collection.errors, status: :unprocessable_entity }
        end
      end
    else
      Rails.logger.warn("Unauthorized to update collection #{@collection.id} (current user: #{current_user.id})")
      redirect_to collections_path
    end
  end
  # rubocop:enable Metrics/MethodLength

  # This is a JSON only endpoint
  def add_admin
    @collection = Collection.find(params[:id])
    @collection.add_administrator(current_user, User.new_for_uid(params[:uid]))
    check_and_render
  end

  # This is a JSON only endpoint
  def add_submitter
    @collection = Collection.find(params[:id])
    @collection.add_submitter(current_user, User.new_for_uid(params[:uid]))
    check_and_render
  end

  # This is a JSON only endpoint
  def delete_user_from_collection
    @collection = Collection.find(params[:id])
    @collection.delete_permission(current_user, User.find_by(uid: params[:uid]))
    check_and_render
  end

  private

    def check_and_render
      if @collection.errors.count > 0 && @collection.errors.first.message == "Unauthorized"
        render status: :unauthorized, json: { message: "Unauthorized" }
      elsif @collection.errors.count > 0
        render status: :bad_request, json: { message: @collection.errors.first.message }
      else
        render status: :ok, json: { message: "OK" }
      end
    end

    # Only allow trusted parameters through.
    def collection_params
      params.require(:collection).permit([:title, :description])
    end

    def can_edit?
      current_user.can_admin? @collection
    end
end
