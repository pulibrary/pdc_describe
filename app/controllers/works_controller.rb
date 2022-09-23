# frozen_string_literal: true

require "nokogiri"
require "open-uri"

# rubocop:disable Metrics/ClassLength
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
# rubocop:disable Style/For
class WorksController < ApplicationController
  around_action :rescue_aasm_error, only: [:approve, :withdraw, :resubmit, :validate, :create]

  skip_before_action :authenticate_user!
  before_action :authenticate_user!, unless: :public_request?

  ##
  # Public requests are requests that do not require authentication.
  # This is to enable PDC Discovery to index approved content via the RSS feed and
  # .json calls to individual works without needing to log in as a user.
  # Note that only approved works can be fetched for indexing.
  def public_request?
    return true if action_name == "index" && request.format.symbol == :rss
    return true if action_name == "show" && request.format.symbol == :json && Work.find(params[:id]).state == "approved"
    false
  end

  def index
    @works = Work.all
    respond_to do |format|
      format.html
      format.rss { render layout: false }
    end
  end

  # Renders the "step 0" information page before creating a new dataset
  def new
    if wizard_mode?
      render "new_submission"
    else
      @work = Work.new(created_by_user_id: current_user.id, collection: current_user.default_collection)
    end
  end

  def create
    @work = Work.new(created_by_user_id: current_user.id, collection_id: params[:collection_id], resource: resource_from_form, user_entered_doi: params["doi"].present?)
    if @work.valid?
      @work.draft!(current_user)
      redirect_to work_url(@work), notice: "Work was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Creates the new dataset
  def new_submission
    default_collection_id = current_user.default_collection.id
    resource = resource_from_form
    work = Work.new(created_by_user_id: current_user.id, collection_id: default_collection_id, resource: resource)
    work.draft!(current_user)
    redirect_to edit_work_path(work, wizard: true)
  end

  ##
  # Show the information for the dataset with the given id
  # When requested as .json, return the internal json resource
  def show
    @work = Work.find(params[:id])
    respond_to do |format|
      format.html do
        @can_curate = current_user.can_admin?(@work.collection)
        @work.mark_new_notifications_as_read(current_user.id)
      end
      format.json { render json: @work.resource }
    end
  end

  def resolve_doi
    @work = Work.find_by_doi(params[:doi])
    redirect_to @work
  end

  def resolve_ark
    @work = Work.find_by_ark(params[:ark])
    redirect_to @work
  end

  # GET /works/1/edit
  def edit
    @work = Work.find(params[:id])
    if current_user && @work.editable_by?(current_user)
      @uploads = @work.uploads
      @wizard_mode = wizard_mode?
      render "edit"
    else
      Rails.logger.warn("Unauthorized attempt to edit work #{@work.id} by user #{current_user.uid}")
      redirect_to root_path
    end
  end

  def update
    @work = Work.find(params[:id])
    @wizard_mode = wizard_mode?

    collection_id_param = params[:collection_id]

    updates = {
      collection_id: collection_id_param,
      resource: resource_from_form
    }

    if @work.approved?
      upload_keys = work_params[:deleted_uploads] || []
      deleted_uploads = WorkUploadsEditService.find_post_curation_uploads(work: @work, upload_keys: upload_keys)

      return head(:forbidden) unless deleted_uploads.empty?
    else
      updated_pre_curation_uploads = WorkUploadsEditService.precurated_file_list(@work, work_params)
      updates[:pre_curation_uploads] = updated_pre_curation_uploads
    end

    if @work.update(updates)
      if @wizard_mode
        redirect_to work_attachment_select_url(@work)
      else
        redirect_to work_url(@work), notice: "Work was successfully updated."
      end
    else
      @uploads = @work.uploads
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
    if pre_curation_uploads_param
      @work.pre_curation_uploads.attach(pre_curation_uploads_param)
      @work.save!
    end

    redirect_to(work_review_path)
  rescue StandardError => active_storage_error
    Rails.logger.error("Failed to attach the file uploads for the work #{@work.doi}: #{active_storage_error}")
    flash[:notice] = "Failed to attach the file uploads for the work #{@work.doi}: #{active_storage_error}. Please contact rdss@princeton.edu for assistance."

    redirect_to work_file_upload_path(@work)
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

  def validate
    @work = Work.find(params[:id])
    @work.submission_notes = params["submission_notes"]
    @uploads = @work.uploads
    @wizard_mode = true
    @work.complete_submission!(current_user)
    redirect_to user_url(current_user)
  end

  def approve
    @work = Work.find(params[:id])
    @work.approve!(current_user)
    redirect_to work_path(@work)
  end

  def withdraw
    @work = Work.find(params[:id])
    @work.withdraw!(current_user)
    redirect_to work_path(@work)
  end

  def resubmit
    @work = Work.find(params[:id])
    @work.resubmit!(current_user)
    redirect_to work_path(@work)
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
    render xml: work.to_xml
  end

  def datacite_validate
    @errors = []
    @work = Work.find(params[:id])
    datacite_xml = Nokogiri::XML(@work.to_xml)
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
      PDCMetadata::Creator.new_person(given_name, family_name, orcid, sequence)
    end

    # rubocop:disable Metrics/CyclomaticComplexity:
    def resource_from_form
      resource = PDCMetadata::Resource.new
      resource.doi = params["doi"] if params["doi"].present?
      resource.ark = params["ark"] if params["ark"].present?
      resource.description = params["description"]
      resource.publisher = params["publisher"] if params["publisher"].present?
      resource.publication_year = params["publication_year"] if params["publication_year"].present?
      resource.rights = PDCMetadata::Rights.find(params["rights_identifier"])

      # Process the titles
      resource.titles << PDCMetadata::Title.new(title: params["title_main"])
      for i in 1..params["existing_title_count"].to_i do
        if params["title_#{i}"].present?
          resource.titles << PDCMetadata::Title.new(title: params["title_#{i}"], title_type: params["title_type_#{i}"])
        end
      end

      for i in 1..params["new_title_count"].to_i do
        if params["new_title_#{i}"].present?
          resource.titles << PDCMetadata::Title.new(title: params["new_title_#{i}"], title_type: params["new_title_type_#{i}"])
        end
      end

      # Process the creators
      for i in 1..params["creator_count"].to_i do
        creator = new_creator(params["given_name_#{i}"], params["family_name_#{i}"], params["orcid_#{i}"], params["sequence_#{i}"])
        resource.creators << creator unless creator.nil?
      end

      resource
    end
    # rubocop:enable Metrics/CyclomaticComplexity:

    def work_params
      params[:work] || params
    end

    def patch_params
      return {} unless params.key?(:patch)

      params[:patch]
    end

    def pre_curation_uploads_param
      return if patch_params.nil?

      patch_params[:pre_curation_uploads]
    end

    def rescue_aasm_error
      yield
    rescue AASM::InvalidTransition => error
      message = error.message
      if @work.errors.count > 0
        message = @work.errors.to_a.join(", ")
      end
      logger.warn("Invalid #{@work.current_transition}: #{error.message} errors: #{message}")
      @errors = ["Cannot #{@work.current_transition}: #{message}"]
      render error_action, status: :unprocessable_entity
    end

    def error_action
      if action_name == "create"
        :new
      elsif action_name == "validate"
        :edit
      else
        :show
      end
    end

    def wizard_mode?
      params[:wizard] == "true"
    end
end
# rubocop:enable Metrics/ClassLength
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/MethodLength
# rubocop:enable Style/For
