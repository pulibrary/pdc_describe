# frozen_string_literal: true

require "nokogiri"
require "open-uri"

# Controller to handle wizard Mode when editing an work
#
# The wizard flow is shown in the [mermaid diagram here](https://github.com/pulibrary/pdc_describe/blob/main/docs/wizard_flow.md).

class WorksWizardController < ApplicationController
  include ERB::Util
  around_action :rescue_aasm_error, only: [:validate, :new_submission_save]

  before_action :load_work, only: [:edit_wizard, :update_wizard, :attachment_select, :attachment_selected,
                                   :file_upload, :file_uploaded, :file_other, :review, :validate,
                                   :readme_select, :readme_uploaded, :readme_uploaded_payload]

  # GET /works/1/edit-wizard
  def edit_wizard
    @wizard_mode = true
    if validate_modification_permissions(work: @work,
                                         uneditable_message: "Can not edit work: #{@work.id} is not editable by #{current_user.uid}",
                                         current_state_message: "Can not edit work: #{@work.id} is not editable in current state by #{current_user.uid}")

      prepare_decorators_for_work_form(@work)
    end
  end

  # PATCH /works/1/update-wizard
  def update_wizard
    edit_helper(:edit_wizard, work_update_additional_path(@work))
  end

  # Prompt to select how to submit their files
  # GET /works/1/attachment_select
  def attachment_select; end

  # User selected a specific way to submit their files
  # POST /works/1/attachment_selected
  def attachment_selected
    @work.files_location = params["attachment_type"]
    @work.save!

    # create a directory for the work if the curator will need to move files by hand
    @work.s3_query_service.create_directory if @work.files_location != "file_upload"

    if params[:save_only] == "true"
      render :attachment_select
    else
      redirect_to file_location_url
    end
  end

  # Allow user to upload files directly
  # GET /works/1/file_upload
  def file_upload
    @work_decorator = WorkDecorator.new(@work, current_user)
  end

  # POST /works/1/upload-files-wizard (called via Uppy)
  def upload_files
    @work = Work.find(params[:id])
    upload_service = WorkUploadsEditService.new(@work, current_user)
    upload_service.update_precurated_file_list(params["files"], [])
  end

  # POST /works/1/file_upload
  def file_uploaded
    upload_service = WorkUploadsEditService.new(@work, current_user)
    # By the time we hit this endpoint files have been uploaded by Uppy submmitting POST requests
    # to /works/1/upload-files-wizard therefore we only need to delete files here and update the upload snapshot.
    @work = upload_service.snapshot_uppy_and_delete_files(deleted_files_param)

    prepare_decorators_for_work_form(@work)
    if params[:save_only] == "true"
      render :file_upload
    else
      redirect_to(work_review_path)
    end
  rescue => ex
    # Notice that we log the URL (rather than @work.doi) because sometimes we are getting a nil @work.
    # The URL will include the ID and might help us troubleshoot the issue further if it happens again.
    # See https://github.com/pulibrary/pdc_describe/issues/1801
    error_message = "Failed to update work snapshot, URL: #{request.url}: #{ex}"
    Rails.logger.error(error_message)
    Honeybadger.notify(error_message)
    flash[:notice] = "Failed to update work snapshot, work: #{@work&.doi}: #{ex}. Please contact rdss@princeton.edu for assistance."

    redirect_to work_file_upload_path(@work)
  end

  # Allow user to indicate where their files are located in the WWW
  # GET /works/1/file_other
  def file_other; end

  # GET /works/1/review
  # POST /works/1/review
  def review
    if request.method == "POST" || request.method == "PATCH"
      @work.location_notes = params["location_notes"]
      @work.save!
      if params[:save_only] == "true"
        render :file_other
      end
    end
  end

  # Validates that the work is ready to be approved
  # POST /works/1/validate-wizard
  # PATCH /works/1/validate-wizard
  def validate
    @work.submission_notes = params["submission_notes"]

    if params[:save_only] == "true"
      @work.save
      render :review
    else
      @work.complete_submission!(current_user)
      redirect_to work_complete_path(@work.id)
    end
  end

  # Show the user the form to select a readme
  # GET /works/1/readme_select
  def readme_select
    readme = Readme.new(@work, current_user)
    @readme = readme.file_name
  end

  # Hit when the user clicks "Save" or "Next" on the README upload process.
  # Notice that this does not really uploads the file, that happens in readme_uploaded_payload.
  # PATCH /works/1/readme_uploaded
  def readme_uploaded
    readme = Readme.new(@work, current_user)
    if params[:save_only] == "true"
      @readme = readme.file_name
      render :readme_select
    else
      redirect_to work_attachment_select_url(@work)
    end
  end

  def files_param
    params["files"]
  end

  # Uploads the README file, called by Uppy.
  # POST /works/1/readme-uploaded-payload
  def readme_uploaded_payload
    raise StandardError("Only one README file can be uploaded.") if files_param.empty?
    raise StandardError("Only one README file can be uploaded.") if files_param.length > 1

    readme_file = files_param.first
    readme = Readme.new(@work, current_user)

    readme_error = readme.attach(readme_file)
    if readme_error.nil?
      render plain: readme.file_name
    else
      # Tell Uppy there was an error uploading the README
      render plain: readme.file_name, status: :internal_server_error
    end
  end

  def file_location_url
    WorkMetadataService.file_location_url(@work)
  end
  helper_method :file_location_url

  private

    def edit_helper(view_name, redirect_url)
      if validate_modification_permissions(work: @work,
                                           uneditable_message: "Can not update work: #{@work.id} is not editable by #{current_user.uid}",
                                           current_state_message: "Can not update work: #{@work.id} is not editable in current state by #{current_user.uid}")
        prepare_decorators_for_work_form(@work)
        if WorkCompareService.update_work(work: @work, update_params:, current_user:)
          if params[:save_only] == "true"
            render view_name
          else
            redirect_to redirect_url
          end
        else
          render view_name, status: :unprocessable_entity
        end
      end
    end

    def load_work
      @work = Work.find(params[:id])
    end

    # @note No testing coverage but not a route, not called
    def patch_params
      return {} unless params.key?(:patch)

      params[:patch]
    end

    # @note No testing coverage but not a route, not called
    def pre_curation_uploads_param
      return if patch_params.nil?

      patch_params[:pre_curation_uploads]
    end

    def deleted_files_param
      deleted_count = (params.dig("work", "deleted_files_count") || "0").to_i
      (1..deleted_count).map { |i| params.dig("work", "deleted_file_#{i}") }.select(&:present?)
    end

    # @note No testing coverage but not a route, not called
    def readme_file_param
      return if patch_params.nil?

      patch_params[:readme_file]
    end

    def rescue_aasm_error
      super
    rescue StandardError => generic_error
      redirect_to root_url, notice: "We apologize, an error was encountered: #{generic_error.message}. Please contact the PDC Describe administrators."
    end

    def redirect_aasm_error(transition_error_message)
      if @work.persisted?
        redirect_to edit_work_wizard_path(id: @work.id), notice: transition_error_message, params:
      else
        redirect_to work_create_new_submission_path(@work), notice: transition_error_message, params:
      end
    end
end
