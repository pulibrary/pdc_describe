# frozen_string_literal: true

require "nokogiri"
require "open-uri"

# rubocop:disable Metrics/ClassLength
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
# rubocop:disable Style/For
class WorksController < ApplicationController
  def index
    @works = Work.all
  end

  # Renders the "step 0" information page before creating a new dataset
  def new_submission; end

  def new
    default_collection_id = current_user.default_collection.id
    work = Work.create_dataset("New Dataset", current_user.id, default_collection_id)
    redirect_to edit_work_path(work, wizard: true)
  end

  def show
    @work = Work.find(params[:id])
    @can_curate = current_user.can_admin?(@work.collection_id)
    @work.mark_new_notifications_as_read(current_user.id)
    if @work.doi
      service = S3QueryService.new(@work.doi)
      @files = service.data_profile
    end
  end

  def edit
    @work = Work.find(params[:id])
    @wizard_mode = params[:wizard] == "true"
  end

  def update
    @work = Work.find(params[:id])
    @wizard_mode = params[:wizard] == "true"

    updated_deposit_uploads = if work_params.key?(:deposit_uploads)
                                work_params[:deposit_uploads]
                              elsif work_params.key?(:replaced_uploads)
                                persisted_deposit_uploads = @work.deposit_uploads
                                replaced_uploads_params = work_params[:replaced_uploads]

                                updated_uploads = []
                                persisted_deposit_uploads.each_with_index do |existing, i|
                                  key = i.to_s

                                  if replaced_uploads_params.key?(key)
                                    replaced = replaced_uploads_params[key]
                                    updated_uploads << replaced
                                  else
                                    updated_uploads << existing.blob
                                  end
                                end

                                updated_uploads
                              end

    title_param = params[:title_main]
    collection_id_param = params[:collection_id]

    updates = {
      title: title_param,
      collection_id: collection_id_param,
      data_cite: datacite_resource_from_form,
      deposit_uploads: updated_deposit_uploads
    }

    if @work.update(updates)
      if @wizard_mode
        redirect_to work_attachment_select_url(@work)
      else
        redirect_to work_url(@work), notice: "Work was successfully updated."
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Prompt to select how to submit their files
  def attachment_select
    @work = Work.find(params[:id])
    @wizard_mode = true
  end

  # User selected a specific way to submit their files
  def attachment_selected
    @work = Work.find(params[:id])
    @wizard_mode = true
    @work.files_location = params["attachment_type"]
    @work.save!
    next_url = case @work.files_location
               when "file_upload"
                 work_file_upload_url(@work)
               when "file_cluster"
                 work_file_cluster_url(@work)
               else
                 work_file_other_url(@work)
               end
    redirect_to next_url
  end

  # Allow user to upload files directly
  def file_upload
    @work = Work.find(params[:id])
  end

  def file_uploaded
    @work = Work.find(params[:id])
    if deposit_uploads_param
      @work.deposit_uploads.attach(deposit_uploads_param)
      @work.save!
    end
    redirect_to(work_review_path)
  end

  # Allow user to indicate where their files are located in the PUL Research Cluster
  def file_cluster
    @work = Work.find(params[:id])
  end

  # Allow user to indicate where their files are located in the WWW
  def file_other
    @work = Work.find(params[:id])
  end

  def review
    @work = Work.find(params[:id])
    if request.method == "POST"
      @work.location_notes = params["location_notes"]
      @work.save!
    end
  end

  def completed
    @work = Work.find(params[:id])
    @work.submission_notes = params["submission_notes"]
    @work.save!
    redirect_to user_url(current_user)
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

  def assign_curator
    work = Work.find(params[:id])
    work.change_curator(params[:uid], current_user)
    if work.errors.count > 0
      render json: { errors: work.errors.map(&:type) }, status: :bad_request
    else
      render json: {}
    end
  rescue => ex
    Rails.logger.error("Error changing curator for work: #{work.id}. Exception: #{ex.message}")
    render json: { errors: ["Cannot save dataset"] }, status: :bad_request
  end

  def add_comment
    work = Work.find(params[:id])
    if params["new-comment"].present?
      work.add_comment(params["new-comment"], current_user)
    end
    redirect_to work_path(id: params[:id])
  end

  # Outputs the Datacite XML representation of the work
  def datacite
    work = Work.find(params[:id])
    render xml: work.datacite_resource.to_xml
  end

  def datacite_validate
    @errors = []
    @work = Work.find(params[:id])
    datacite_xml = Nokogiri::XML(@work.datacite_resource.to_xml)
    schema_location = Rails.root.join("config", "schema")
    Dir.chdir(schema_location) do
      xsd = Nokogiri::XML::Schema(File.read("datacite_4_4.xsd"))
      xsd.validate(datacite_xml).each do |error|
        @errors << error
      end
    end
  end

  private

    def new_creator(given_name, family_name, orcid, sequence)
      return if family_name.blank? && given_name.blank? && orcid.blank?
      PULDatacite::Creator.new_person(given_name, family_name, orcid, sequence)
    end

    def datacite_resource_from_form
      resource = PULDatacite::Resource.new

      resource.description = params["description"]
      resource.publisher = params["publisher"]
      resource.publication_year = params["publication_year"]

      # Process the titles
      resource.titles << PULDatacite::Title.new(title: params["title_main"])
      for i in 1..params["existing_title_count"].to_i do
        if params["title_#{i}"].present?
          resource.titles << PULDatacite::Title.new(title: params["title_#{i}"], title_type: params["title_type_#{i}"])
        end
      end

      for i in 1..params["new_title_count"].to_i do
        if params["new_title_#{i}"].present?
          resource.titles << PULDatacite::Title.new(title: params["new_title_#{i}"], title_type: params["new_title_type_#{i}"])
        end
      end

      # Process the creators
      for i in 1..params["creator_count"].to_i do
        creator = new_creator(params["given_name_#{i}"], params["family_name_#{i}"], params["orcid_#{i}"], params["sequence_#{i}"])
        resource.creators << creator unless creator.nil?
      end

      resource.to_json
    end

    def work_params
      params[:work] || params
    end

    def patch_params
      return {} unless params.key?(:patch)

      params[:patch]
    end

    def deposit_uploads_param
      return if patch_params.nil?

      patch_params[:deposit_uploads]
    end
end
# rubocop:enable Metrics/ClassLength
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
# rubocop:enable Style/For
