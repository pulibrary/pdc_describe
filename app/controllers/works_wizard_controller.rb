# frozen_string_literal: true

require "nokogiri"
require "open-uri"

# Controller to handle wizard Mode when editing an work
#
# The wizard flow is as follows:
# new_submission -> new_submission_save -> edit_wizard -> update_wizard -> readme_select -> readme_uploaded -> attachment_select ->
#     attachment_selected -> file_other ->                  review -> validate -> [ work controller ] show & file_list
#                         \> file_upload -> file_uploaded -^

class WorksWizardController < ApplicationController
  include ERB::Util
  around_action :rescue_aasm_error, only: [:validate, :new_submission_save]

  before_action :load_work, only: [:edit_wizard, :update_wizard, :attachment_select, :attachment_selected,
                                   :file_upload, :file_uploaded, :file_other, :review, :validate,
                                   :readme_select, :readme_uploaded, :update_additional_save, :update_additional]

  # get Renders the "step 0" information page before creating a new dataset
  # GET /works/new_submission
  def new_submission
    @work = WorkMetadataService.new(params:, current_user:).work_for_new_submission
    prepare_decorators_for_work_form(@work)
  end

  # Creates the new dataset or update the dataset is save only was done previously
  # POST /works/new_submission or POST /works/1/new_submission
  def new_submission_save
    @work = WorkMetadataService.new(params:, current_user:).new_submission
    @errors = @work.errors.to_a
    if @errors.count.positive?
      prepare_decorators_for_work_form(@work)
      render :new_submission
    else
      redirect_to edit_work_wizard_path(@work)
    end
  end

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

  # get /works/1/update-additional
  def update_additional
    prepare_decorators_for_work_form(@work)
  end

  # PATCH /works/1/update-additional
  def update_additional_save
    edit_helper(:update_additional, work_readme_select_path(@work))
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
  def file_upload; end

  # POST /works/1/file_upload
  def file_uploaded
    files = pre_curation_uploads_param || []
    if files.count > 0
      upload_service = WorkUploadsEditService.new(@work, current_user)
      @work = upload_service.update_precurated_file_list(files, [])
      @work.reload_snapshots
    end
    if params[:save_only] == "true"
      render :file_upload
    else
      redirect_to(work_review_path)
    end
  rescue StandardError => active_storage_error
    Rails.logger.error("Failed to attach the file uploads for the work #{@work.doi}: #{active_storage_error}")
    flash[:notice] = "Failed to attach the file uploads for the work #{@work.doi}: #{active_storage_error}. Please contact rdss@princeton.edu for assistance."

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
  # GET /works/1/validate
  def validate
    @work.submission_notes = params["submission_notes"]
    if params[:save_only] == "true"
      @work.save
      render :review
    else
      @work.complete_submission!(current_user)
      redirect_to user_url(current_user)
    end
  end

  # Show the user the form to select a readme
  # GET /works/1/readme_select
  def readme_select
    readme = Readme.new(@work, current_user)
    @readme = readme.file_name
  end

  # Uploads the readme the user selects
  # GET /works/1/readme_uploaded
  def readme_uploaded
    readme = Readme.new(@work, current_user)
    readme_error = readme.attach(readme_file_param)
    if readme_error.nil?
      if params[:save_only] == "true"
        @readme = readme.file_name
        render :readme_select
      else
        redirect_to work_attachment_select_url(@work)
      end
    else
      flash[:notice] = readme_error
      redirect_to work_readme_select_url(@work)
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

    def rescue_aasm_error
      super
    rescue StandardError => generic_error
      redirect_to root_url, notice: "We apologize, an error was encountered: #{generic_error.message}. Please contact the PDC Describe administrators."
    end

    def redirect_aasm_error(transition_error_message)
      if @work.persisted?
        redirect_to edit_work_wizard_path(id: @work.id), notice: transition_error_message, params:
      else
        redirect_to work_create_new_submission_path, notice: transition_error_message, params:
      end
    end
end
# rubocop:enable Metrics/ClassLength
