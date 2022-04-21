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
      redirect_to collection_path(@collection)
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
