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
                                   :readme_select, :readme_uploaded]

  # get Renders the "step 0" information page before creating a new dataset
  # GET /works/1/new_submission
  def new_submission
    group = Group.find_by(code: params[:group_code]) || current_user.default_group
    group_id = group.id
    @work = Work.new(created_by_user_id: current_user.id, group_id:)
    @work_decorator = WorkDecorator.new(@work, current_user)
    @form_resource_decorator = FormResourceDecorator.new(@work, current_user)
  end

  # Creates the new dataset
  # POST /works/1/new_submission
  def new_submission_save
    group = Group.find_by(code: params[:group_code]) || current_user.default_group
    group_id = group.id
    @work = Work.new(created_by_user_id: current_user.id, group_id:)
    @work.resource = FormToResourceService.convert(params, @work)
    @work.draft!(current_user)
    redirect_to edit_work_wizard_path(@work)
  end

  # GET /works/1/edit_wizard
  def edit_wizard
    @work_decorator = WorkDecorator.new(@work, current_user)
    @wizard_mode = true
    if validate_modification_permissions(work: @work,
                                         uneditable_message: "Can not edit work: #{@work.id} is not editable by #{current_user.uid}",
                                         current_state_message: "Can not edit work: #{@work.id} is not editable in current state by #{current_user.uid}")

      @form_resource_decorator = FormResourceDecorator.new(@work, current_user)
    end
  end

  # PATCH /works/1/update-wizard
  def update_wizard
    if validate_modification_permissions(work: @work,
                                         uneditable_message: "Can not update work: #{@work.id} is not editable by #{current_user.uid}",
                                         current_state_message: "Can not update work: #{@work.id} is not editable in current state by #{current_user.uid}")
      work_before = @work.dup
      if @work.update(update_params)
        work_compare = WorkCompareService.new(work_before, @work)
        @work.log_changes(work_compare, current_user.id)

        redirect_to work_readme_select_url(@work)
      else
        # This is needed for rendering HTML views with validation errors
        @form_resource_decorator = FormResourceDecorator.new(@work, current_user)

        render :edit_wizard, status: :unprocessable_entity
      end
    end
  end

  # Prompt to select how to submit their files
  # GET /works/1/attachment_select
  def attachment_select
    @wizard_mode = true
  end

  # User selected a specific way to submit their files
  # POST /works/1/attachment_selected
  def attachment_selected
    @wizard_mode = true
    @work.files_location = params["attachment_type"]
    @work.save!

    # create a directory for the work if the curator will need to move files by hand
    @work.s3_query_service.create_directory if @work.files_location != "file_upload"

    next_url = case @work.files_location
               when "file_upload"
                 work_file_upload_url(@work)
               else
                 work_file_other_url(@work)
               end
    redirect_to next_url
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
      @work.save!
      @work.reload_snapshots
    end
    redirect_to(work_review_path)
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
    if request.method == "POST"
      @work.location_notes = params["location_notes"]
      @work.save!
    end
  end

  # Validates that the work is ready to be approved
  # GET /works/1/validate
  def validate
    @work.submission_notes = params["submission_notes"]
    @work.complete_submission!(current_user)
    redirect_to user_url(current_user)
  end

  # Show the user the form to select a readme
  # GET /works/1/readme_select
  def readme_select
    readme = Readme.new(@work, current_user)
    @readme = readme.file_name
    @wizard = true
  end

  # Uploads the readme the user selects
  # GET /works/1/readme_uploaded
  def readme_uploaded
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

  private

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
      yield
    rescue AASM::InvalidTransition => error
      message = message_from_assm_error(aasm_error: error, work: @work)

      Honeybadger.notify("Invalid #{@work.current_transition}: #{error.message} errors: #{message}")
      transition_error_message = "We apologize, the following errors were encountered: #{message}. Please contact the PDC Describe administrators for any assistance."
      @errors = [transition_error_message]

      if @work.persisted?
        redirect_to edit_work_wizard_path(id: @work.id), notice: transition_error_message, params:
      else
        @form_resource_decorator = FormResourceDecorator.new(@work, current_user)
        redirect_to work_create_new_submission_path, notice: transition_error_message, params:
      end
    rescue StandardError => generic_error
      redirect_to root_url, notice: "We apologize, an error was encountered: #{generic_error.message}. Please contact the PDC Describe administrators."
    end
end
# rubocop:enable Metrics/ClassLength
