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
    if can_edit?
      uid = params[:uid]
      collection_id = params[:id]
      user = User.new_for_uid(uid)
      if user.can_admin?(collection_id)
        render status: :bad_request, json: { message: "User has already been added" }
      else
        UserCollection.add_admin(user.id, collection_id)
        render status: :ok, json: { message: "OK" }
      end
    else
      render status: :unauthorized, json: { message: "Unauthorized" }
    end
  end

  # This is a JSON only endpoint
  def add_submitter
    @collection = Collection.find(params[:id])
    if can_edit?
      uid = params[:uid]
      collection_id = params[:id]
      user = User.new_for_uid(uid)
      if user.can_submit?(collection_id)
        render status: :bad_request, json: { message: "User has already been added" }
      else
        UserCollection.add_submitter(user.id, collection_id)
        render status: :ok, json: { message: "OK" }
      end
    else
      render status: :unauthorized, json: { message: "Unauthorized" }
    end
  end

  # This is a JSON only endpoint
  # rubocop:disable Metrics/MethodLength
  def delete_user_from_collection
    @collection = Collection.find(params[:id])
    if can_edit?
      uid = params[:uid]
      if uid == current_user.uid
        render status: :bad_request, json: { message: "Cannot remove yourself from a collection. Contact a super-admin for help." }
      else
        collection_id = params[:id]
        user = User.where(uid: uid).first
        if user.nil?
          render status: :bad_request, json: { message: "User was not found" }
        else
          UserCollection.where(user_id: user.id, collection_id: collection_id).each(&:delete)
          render status: :ok, json: { message: "OK" }
        end
      end
    else
      render status: :unauthorized, json: { message: "Unauthorized" }
    end
  end
  # rubocop:enable Metrics/MethodLength

  private

    # Only allow trusted parameters through.
    def collection_params
      params.require(:collection).permit([:title, :description])
    end

    def can_edit?
      current_user.can_admin?(@collection.id)
    end
end
