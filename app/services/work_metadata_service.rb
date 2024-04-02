# frozen_string_literal: true

# A place to move the logic to from the work controllers
#   Process the parameters and permissions to update a work
class WorkMetadataService
  attr_reader :params, :current_user

  # @params [User] current_user the user who is currently logged in
  # @param [HashWithIndifferentAccess] update_params values to update the work with
  def initialize(params:, current_user:)
    @params = params
    @current_user = current_user
  end

  # creates or finds the work for the new submission form based on the parameters
  #
  # @returns the new or updated work
  def work_for_new_submission
    if params[:id].present?
      Work.find(params[:id])
    else
      group = Group.find_by(code: params[:group_code]) || current_user.default_group
      Work.new(created_by_user_id: current_user.id, group_id: group.id)
    end
  end

  # generates or load the work for a new submission based on the parameters
  #
  # @returns the new or updated work
  def new_submission
    if params[:id].present?
      update_work
    else
      draft_work
    end
  end

  def self.file_location_url(work)
    if work.files_location == "file_upload"
      Rails.application.routes.url_helpers.work_file_upload_path(work)
    else
      Rails.application.routes.url_helpers.work_file_other_path(work)
    end
  end

private

  def update_work
    work = Work.find(params[:id])
    update_params = { group: group_code, resource: FormToResourceService.convert(params, work) }
    WorkCompareService.update_work(work:, update_params:, current_user:)
    work
  end

  def draft_work
    group_id = group_code.id
    work = Work.new(created_by_user_id: current_user.id, group_id:)
    work.resource = FormToResourceService.convert(params, work)
    if work.valid_to_draft
      work.draft!(current_user)
    end
    work
  end

  def group_code
    @group_code ||= Group.find_by(code: params[:group_code]) || current_user.default_group
  end
end
