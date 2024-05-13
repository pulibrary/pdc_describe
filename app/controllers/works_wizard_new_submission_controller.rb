# frozen_string_literal: true

require "nokogiri"
require "open-uri"

# Controller to handle the policy agreement acknowlegdement before the wizard is started
#
# The wizard flow is shown in the [mermaid diagram here](https://github.com/pulibrary/pdc_describe/blob/main/docs/wizard_flow.md).
#
class WorksWizardNewSubmissionController < ApplicationController
  before_action :load_work
  before_action :can_edit

  # get Renders the "step 0" information page before creating a new dataset
  # GET /works/1/new_submission
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

  # GET /works/1/new-submission-delete
  def new_submission_delete
    if @work.editable_by?(current_user) && @work.none?
      @work.destroy
    end
    redirect_to user_path(current_user)
  end

  private

    def load_work
      @work = Work.find(params[:id])
    end

    def can_edit
      return if @work.editable_by?(current_user)

      redirect_to user_path(current_user), notice: "You do not have permission to modify the work."
    end
end
