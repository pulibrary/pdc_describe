# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
# rubocop:disable Style/For
class WorksController < ApplicationController
  def index
    @works = Work.all
  end

  def new_submission; end

  def new
    default_collection_id = current_user.default_collection.id
    work = Work.create_dataset("New Dataset", current_user.id, default_collection_id)
    redirect_to edit_work_path(work)
  end

  def show
    @work = Work.find(params[:id])
    if @work.doi
      service = S3QueryService.new(@work.doi)
      @files = service.data_profile
    end
  end

  def edit
    @work = Work.find(params[:id])
  end

  def update
    @work = Work.find(params[:id])
    respond_to do |format|
      work_params = {
        title: params[:title_main],
        collection_id: params[:collection_id],
        data_cite: datacite_resource_from_form
      }
      if @work.update(work_params)
        format.html { redirect_to work_url(@work), notice: "Work was successfully updated." }
        format.json { render :show, status: :ok, location: @work }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @work.errors, status: :unprocessable_entity }
      end
    end
  end

  def approve
    work = Work.find(params[:id])
    work.approve(current_user)
    redirect_to work_path(work)
  end

  def withdraw
    work = Work.find(params[:id])
    work.withdraw(current_user)
    redirect_to work_path(work)
  end

  def resubmit
    work = Work.find(params[:id])
    work.resubmit(current_user)
    redirect_to work_path(work)
  end

  # Outputs the Datacite XML representation of the work
  def datacite
    work = Work.find(params[:id])
    render xml: work.datacite_resource.to_xml
  end

  private

    def new_creator(given_name, family_name, orcid)
      return if family_name.blank? && given_name.blank? && orcid.blank?
      Datacite::Creator.new_person(given_name, family_name, orcid)
    end

    def datacite_resource_from_form
      resource = Datacite::Resource.new

      resource.publisher = params["publisher"]
      resource.publication_year = params["publication_year"]

      # Process the titles
      resource.titles << Datacite::Title.new(title: params["title_main"])
      for i in 1..params["existing_title_count"].to_i do
        if params["title_#{i}"].present?
          resource.titles << Datacite::Title.new(title: params["title_#{i}"], title_type: params["title_type_#{i}"])
        end
      end

      for i in 1..params["new_title_count"].to_i do
        if params["new_title_#{i}"].present?
          resource.titles << Datacite::Title.new(title: params["new_title_#{i}"], title_type: params["new_title_type_#{i}"])
        end
      end

      # Process the creators
      for i in 1..params["creator_count"].to_i do
        creator = new_creator(params["given_name_#{i}"], params["family_name_#{i}"], params["orcid_#{i}"])
        resource.creators << creator unless creator.nil?
      end

      resource.to_json
    end
end
# rubocop:enable Metrics/ClassLength
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
# rubocop:enable Style/For
