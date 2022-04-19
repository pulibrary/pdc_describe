# frozen_string_literal: true
class DatasetsController < ApplicationController
  def index
    @datasets = Dataset.all
  end

  def new
    default_collection_id = current_user.default_collection.id
    dataset = Dataset.create_skeleton("New Dataset", current_user.id, default_collection_id)
    redirect_to edit_dataset_path(dataset)
  end

  def show
    @dataset = Dataset.find(params[:id])
  end

  def edit
    @dataset = Dataset.find(params[:id])
  end

  def update
    @dataset = Dataset.find(params[:id])
    respond_to do |format|
      # Update the values in the work table
      work = Work.find(form_params[:work_id])
      work.update(work_params)
      work.save!

      # And then update the dataset
      if @dataset.update(dataset_params)
        format.html { redirect_to dataset_url(@dataset), notice: "Dataset was successfully updated." }
        format.json { render :show, status: :ok, location: @dataset }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  def approve
    dataset = Dataset.find(params[:id])
    dataset.work.approve
    redirect_to dataset_path(dataset)
  end

  def withdraw
    dataset = Dataset.find(params[:id])
    dataset.work.withdraw
    redirect_to dataset_path(dataset)
  end

  def resubmit
    dataset = Dataset.find(params[:id])
    dataset.work.resubmit
    redirect_to dataset_path(dataset)
  end

  private

    # Only allow a list of trusted parameters through.
    def form_params
      params.require(:dataset).permit([:title, :work_id, :collection_id, :ark])
    end

    def work_params
      {
        title: form_params[:title],
        collection_id: form_params[:collection_id]
      }
    end

    def dataset_params
      form_params.reject { |x| x.in?(["title", "work_id"]) }
    end
end
