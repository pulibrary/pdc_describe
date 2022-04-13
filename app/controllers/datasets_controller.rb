# frozen_string_literal: true
class DatasetsController < ApplicationController
  def index
    @my_datasets = Dataset.where(created_by_user_id: current_user.id)
    @other_datasets = Dataset.where("created_by_user_id != :user_id", {user_id: current_user.id})
  end

  def new
    default_collection_id = current_user.default_collection.id
    @dataset = Dataset.create_skeleton("title", current_user.id, default_collection_id)
    redirect_to dataset_url(@dataset)
  end

  def show
    id = params[:id]
    @dataset = Dataset.find(id)
  end
end
