# frozen_string_literal: true
class DatasetsController < ApplicationController
  def index
    @datasets = Dataset.all
  end

  def dashboard
    @my_datasets = Dataset.where(created_by_user_id: current_user.id)
    @my_collections = current_user.submitter_collections
  end

  def new
    default_collection_id = current_user.default_collection.id
    @dataset = Dataset.create_skeleton("New Dataset", current_user.id, default_collection_id)
    render "edit"
  end

  def show
    id = params[:id]
    @dataset = Dataset.find(id)
  end

  def edit
    @dataset = Dataset.find(params[:id])
  end

  def update
    @dataset = Dataset.find(params[:id])
    respond_to do |format|
      if @dataset.update(dataset_params)
        format.html { redirect_to dataset_url(@dataset), notice: "Dataset was successfully updated." }
        format.json { render :show, status: :ok, location: @dataset }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  private

    # Only allow a list of trusted parameters through.
    def dataset_params
      params.require(:dataset).permit([:title, :collection_id, :ark])
    end
end
