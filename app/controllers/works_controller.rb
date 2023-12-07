# frozen_string_literal: true

require "nokogiri"
require "open-uri"

# rubocop:disable Metrics/ClassLength
class WorksController < ApplicationController
  include ERB::Util
  around_action :rescue_aasm_error, only: [:approve, :withdraw, :resubmit, :validate, :create, :new_submission]

  skip_before_action :authenticate_user!
  before_action :authenticate_user!, unless: :public_request?

  def index
    @works = Work.all
    respond_to do |format|
      format.html
      format.rss { render layout: false }
    end
  end

  # Renders the "step 0" information page before creating a new dataset
  def new
    group = Group.find_by(code: params[:group_code]) || current_user.default_group
    @work = Work.new(created_by_user_id: current_user.id, group:)
    @form_resource_decorator = FormResourceDecorator.new(@work, current_user)
    if wizard_mode?
      render "new_submission"
    end
  end

  def create
    @work = Work.new(created_by_user_id: current_user.id, group_id: params_group_id, user_entered_doi: params["doi"].present?)
    @work.resource = FormToResourceService.convert(params, @work)
    @work.resource.migrated = migrated?
    if @work.valid?
      @work.draft!(current_user)
      upload_service = WorkUploadsEditService.new(@work, current_user)
      upload_service.update_precurated_file_list(added_files_param, deleted_files_param)
      redirect_to work_url(@work), notice: "Work was successfully created."
    else
      @form_resource_decorator = FormResourceDecorator.new(@work, current_user)
      render :new, status: :unprocessable_entity
    end
  end

  # Creates the new dataset
  def new_submission
    default_group_id = current_user.default_group.id
    @work = Work.new(created_by_user_id: current_user.id, group_id: default_group_id)
    @work.resource = FormToResourceService.convert(params, @work)
    @work.draft!(current_user)
    redirect_to edit_work_path(@work, wizard: true)
  end

  ##
  # Show the information for the dataset with the given id
  # When requested as .json, return the internal json resource
  def show
    @work = Work.find(params[:id])
    UpdateSnapshotJob.perform_later(work_id: @work.id, last_snapshot_id: work.upload_snapshots.first&.id)
    @work_decorator = WorkDecorator.new(@work, current_user)

    respond_to do |format|
      format.html do
        # Ensure that the Work belongs to a Group
        group = @work_decorator.group
        raise(Work::InvalidGroupError, "The Work #{@work.id} does not belong to any Group") unless group

        @can_curate = current_user.can_admin?(group)
        @work.mark_new_notifications_as_read(current_user.id)
      end
      format.json { render json: @work.to_json }
    end
  end

  def file_list
    if params[:id] == "NONE"
      # This is a special case when we render the file list for a work being created
      # (i.e. it does not have an id just yet)
      render json: []
    else
      @work = Work.find(params[:id])
      render json: @work.file_list
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
      if @work.approved? && !@work.administered_by?(current_user)
        Honeybadger.notify("Can not edit work: #{@work.id} is approved but #{current_user.uid} is not admin")
        redirect_to root_path, notice: I18n.t("works.uneditable.approved")
      else
        @uploads = @work.uploads
        @wizard_mode = wizard_mode?
        @form_resource_decorator = FormResourceDecorator.new(@work, current_user)
        render "edit"
      end
    else
      Honeybadger.notify("Can not edit work: #{@work.id} is not editable by #{current_user.uid}")
      redirect_to root_path, notice: I18n.t("works.uneditable.privs")
    end
  end

  def update
    @work = Work.find(params[:id])
    if current_user.blank? || !@work.editable_by?(current_user)
      Honeybadger.notify("Can not update work: #{@work.id} is not editable by #{current_user.uid}")
      redirect_to root_path, notice: I18n.t("works.uneditable.privs")
    elsif !@work.editable_in_current_state?(current_user)
      Honeybadger.notify("Can not update work: #{@work.id} is not editable in current state by #{current_user.uid}")
      redirect_to root_path, notice: I18n.t("works.uneditable.approved")
    else
      update_work
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

    # create a directory for the work if the curator will need to move files by hand
    @work.s3_query_service.create_directory if @work.files_location != "file_upload"

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
    files = pre_curation_uploads_param || []
    if files.count > 0
      upload_service = WorkUploadsEditService.new(@work, current_user)
      @work = upload_service.update_precurated_file_list(files, [])
      @work.save!
      @work.reload_snapshots
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
    flash[:notice] = "Your files are being moved to the post-curation bucket in the background. Depending on the file sizes this may take some time."
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

  def add_message
    work = Work.find(params[:id])
    if params["new-message"].present?
      new_message_param = params["new-message"]
      sanitized_new_message = html_escape(new_message_param)

      work.add_message(sanitized_new_message, current_user.id)
    end
    redirect_to work_path(id: params[:id])
  end

  def add_provenance_note
    work = Work.find(params[:id])
    if params["new-provenance-note"].present?
      new_date = params["new-provenance-date"]
      new_label = params["change_label"]
      new_note = html_escape(params["new-provenance-note"])

      work.add_provenance_note(new_date, new_note, current_user.id, new_label)
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
    validator = WorkValidator.new(@work)
    unless validator.valid_datacite?
      @errors = @work.errors.full_messages
    end
  end

  def readme_select
    @work = Work.find(params[:id])
    readme = Readme.new(@work, current_user)
    @readme = readme.file_name
    @wizard = true
  end

  def readme_uploaded
    @work = Work.find(params[:id])
    @wizard = true
    readme = Readme.new(@work, current_user)
    readme_error = readme.attach(readme_file_param)
    if readme_error.nil?
      redirect_to work_attachment_select_url(@work)
    else
      flash[:notice] = readme_error
      redirect_to work_readme_select_url(@work)
    end
  end

  def migrating?
    return @work.resource.migrated if @work&.resource && !params.key?(:migrate)

    params[:migrate]
  end
  helper_method :migrating?

  def doi_mutable?
    return true unless !@work.nil? && @work.persisted?

    !@work.approved?
  end
  helper_method :doi_mutable?

  # Returns the raw BibTex citation information
  def bibtex
    work = Work.find(params[:id])
    creators = work.resource.creators.map { |creator| "#{creator.family_name}, #{creator.given_name}" }
    citation = DatasetCitation.new(creators, [work.resource.publication_year], work.resource.titles.first.title, work.resource.resource_type, work.resource.publisher, work.resource.doi)
    bibtex = citation.bibtex
    send_data bibtex, filename: "#{citation.bibtex_id}.bibtex", type: "text/plain", disposition: "attachment"
  end

  private

    # Extract the Work ID parameter
    # @return [String]
    def work_id_param
      params[:id]
    end

    # Find the Work requested by ID
    # @return [Work]
    def work
      Work.find(work_id_param)
    end

    # Determine whether or not the request is for the :index action in the RSS
    # response format
    # This is to enable PDC Discovery to index approved content via the RSS feed
    def rss_index_request?
      action_name == "index" && request.format.symbol == :rss
    end

    # Determine whether or not the request is for the :show action in the JSON
    # response format
    # @return [Boolean]
    def json_show_request?
      action_name == "show" && request.format.symbol == :json
    end

    # Determine whether or not the requested Work has been approved
    # @return [Boolean]
    def work_approved?
      work&.state == "approved"
    end

    ##
    # Public requests are requests that do not require authentication.
    # This is to enable PDC Discovery to index approved content via the RSS feed
    # and .json calls to individual works without needing to log in as a user.
    # Note that only approved works can be fetched for indexing.
    def public_request?
      return true if rss_index_request?
      return true if json_show_request? && work_approved?
      false
    end

    def work_params
      params[:work] || {}
    end

    def patch_params
      return {} unless params.key?(:patch)

      params[:patch]
    end

    def pre_curation_uploads_param
      return if patch_params.nil?

      patch_params[:pre_curation_uploads]
    end

    def readme_file_param
      return if patch_params.nil?

      patch_params[:readme_file]
    end

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/BlockNesting
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/PerceivedComplexity
    def rescue_aasm_error
      yield
    rescue AASM::InvalidTransition => error
      message = error.message
      if @work.errors.count > 0
        message = @work.errors.to_a.join(", ")
      end
      message.chop! if message.last == "."
      Honeybadger.notify("Invalid #{@work.current_transition}: #{error.message} errors: #{message}")
      transition_error_message = "We apologize, the following errors were encountered: #{message}. Please contact the PDC Describe administrators for any assistance."
      @errors = [transition_error_message]

      if @work.persisted?
        redirect_to edit_work_url(id: @work.id), notice: transition_error_message, params:
      else
        new_params = {}
        new_params[:wizard] = wizard_mode? if wizard_mode?
        new_params[:migrate] = migrating? if migrating?
        @form_resource_decorator = FormResourceDecorator.new(@work, current_user)
        redirect_to new_work_url(params: new_params), notice: transition_error_message, params: new_params
      end
    rescue StandardError => generic_error
      if action_name == "create"
        if @work.persisted?
          Honeybadger.notify("Failed to create the new Dataset #{@work.id}: #{generic_error.message}")
          @form_resource_decorator = FormResourceDecorator.new(@work, current_user)
          redirect_to edit_work_url(id: @work.id), notice: "Failed to create the new Dataset #{@work.id}: #{generic_error.message}", params:
        else
          Honeybadger.notify("Failed to create a new Dataset #{@work.id}: #{generic_error.message}")
          new_params = {}
          new_params[:wizard] = wizard_mode? if wizard_mode?
          new_params[:migrate] = migrating? if migrating?
          @form_resource_decorator = FormResourceDecorator.new(@work, current_user)
          redirect_to new_work_url(params: new_params), notice: "Failed to create a new Dataset: #{generic_error.message}", params: new_params
        end
      else
        redirect_to root_url, notice: "We apologize, an error was encountered: #{generic_error.message}. Please contact the PDC Describe administrators."
      end
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/BlockNesting
    # rubocop:enable Metrics/AbcSize

    def error_action
      @form_resource_decorator = FormResourceDecorator.new(@work, current_user)
      if action_name == "create"
        :new
      elsif action_name == "validate"
        :edit
      elsif action_name == "new_submission"
        :new_submission
      else
        @work_decorator = WorkDecorator.new(@work, current_user)
        :show
      end
    end

    def wizard_mode?
      params[:wizard] == "true"
    end

    def update_work
      @wizard_mode = wizard_mode?
      upload_service = WorkUploadsEditService.new(@work, current_user)
      if @work.approved?
        upload_keys = deleted_files_param || []
        deleted_uploads = upload_service.find_post_curation_uploads(upload_keys:)

        return head(:forbidden) unless deleted_uploads.empty?
      else
        @work = upload_service.update_precurated_file_list(added_files_param, deleted_files_param)
      end

      process_updates
    end

    def embargo_date_param
      params["embargo-date"]
    end

    def embargo_date
      return nil if embargo_date_param.blank?

      Date.parse(embargo_date_param)
    rescue Date::Error
      Rails.logger.error("Failed to parse the embargo date #{embargo_date_param} for Work #{@work.id}")
      nil
    end

    def update_params
      {
        group_id: params_group_id,
        embargo_date:,
        resource: FormToResourceService.convert(params, @work)
      }
    end

    def added_files_param
      Array(work_params[:pre_curation_uploads_added])
    end

    def deleted_files_param
      deleted_count = (work_params["deleted_files_count"] || "0").to_i
      (1..deleted_count).map { |i| work_params["deleted_file_#{i}"] }.select(&:present?)
    end

    def process_updates
      resource_before = @work.resource
      if @work.update(update_params)
        resource_compare = ResourceCompareService.new(resource_before, update_params[:resource])
        @work.log_changes(resource_compare, current_user.id)

        if @wizard_mode
          redirect_to work_readme_select_url(@work)
        else
          redirect_to work_url(@work), notice: "Work was successfully updated."
        end
      else
        # This is needed for rendering HTML views with validation errors
        @uploads = @work.uploads
        @wizard_mode = wizard_mode?
        @form_resource_decorator = FormResourceDecorator.new(@work, current_user)

        render :edit, status: :unprocessable_entity
      end
    end

    def params_group_id
      # Do not allow a nil for the group id
      @params_group_id ||= begin
        group_id = params[:group_id]
        if group_id.blank?
          group_id = current_user.default_group.id
          Honeybadger.notify("We got a nil group as part of the parameters #{params} #{request}")
        end
        group_id
      end
    end

    def migrated?
      return false unless params.key?(:submit)

      params[:submit] == "Migrate"
    end
end
# rubocop:enable Metrics/ClassLength
