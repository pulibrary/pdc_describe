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
    work = Work.find(@dataset.work_id)
    @datacite = Datacite::Resource.new_from_json(work.data_cite)

    if @dataset.doi
      service = S3QueryService.new(@dataset.doi)
      @files = service.data_profile
    end
  end

  def edit
    @dataset = Dataset.find(params[:id])
    work = Work.find(@dataset.work_id)
    @datacite = Datacite::Resource.new_from_json(work.data_cite)
  end

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def update
    @dataset = Dataset.find(params[:id])
    respond_to do |format|
      update_work_record
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
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize

  def approve
    dataset = Dataset.find(params[:id])
    dataset.work.approve(current_user)
    redirect_to dataset_path(dataset)
  end

  def withdraw
    dataset = Dataset.find(params[:id])
    dataset.work.withdraw(current_user)
    redirect_to dataset_path(dataset)
  end

  def resubmit
    dataset = Dataset.find(params[:id])
    dataset.work.resubmit(current_user)
    redirect_to dataset_path(dataset)
  end

  # Outputs the Datacite XML representation of the dataset
  def datacite
    @dataset = Dataset.find(params[:id])
    work = Work.find(@dataset.work_id)
    resource = Datacite::Resource.new_from_json(work.data_cite)
    render xml: resource.to_xml
  end

  private

    # Only allow a list of trusted parameters through.
    def form_params
      valid_list = [:title, :work_id, :collection_id, :alternative_title, :new_orcid, :new_family_name, :new_given_name]
      params.require(:dataset).permit(valid_list)
    end

    def work_params
      {
        title: form_params[:title],
        collection_id: form_params[:collection_id]
      }
    end

    def dataset_params
      form_params.reject { |x| x.in?(["title", "collection_id", "alternative_title"]) }
    end

    def new_creator(given_name, family_name, orcid)
      return if family_name.blank? && given_name.blank? && orcid.blank?
      Datacite::Creator.new_person(given_name, family_name, orcid)
    end

    # Populate the work.data_cite field
    def update_work_record
      work = Work.find(form_params[:work_id])
      work_data = work_params
      resource = Datacite::Resource.new(title: form_params[:title])

      if params["alternative_title"].present?
        resource.titles << Datacite::Title.new(title: params["alternative_title"], title_type: "AlternativeTitle")
      end

      for i in 1..params["existing_creator_count"].to_i do
        creator = new_creator(params["given_name_#{i}"], params["family_name_#{i}"], params["orcid_#{i}"])
        resource.creators << creator unless creator.nil?
      end

      for i in 1..params["new_creator_count"].to_i do
        creator = new_creator(params["new_given_name_#{i}"], params["new_family_name_#{i}"], params["new_orcid_#{i}"])
        resource.creators << creator unless creator.nil?
      end

      work_data[:data_cite] = resource.to_json
      work.update(work_data)
      work.save!
    end
end
