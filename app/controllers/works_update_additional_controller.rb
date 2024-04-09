# frozen_string_literal: true

require "nokogiri"
require "open-uri"

# Controller to handle the update Additional Metadata step in wizard Mode when editing an work
#
# The wizard flow is as follows:
# new_submission -> new_submission_save -> edit_wizard -> update_wizard -> update_additional -> update_additional_save ->readme_select -> readme_uploaded -> attachment_select ->
#     attachment_selected -> file_other ->                  review -> validate -> [ work controller ] show & file_list
#                         \> file_upload -> file_uploaded -^

class WorksUpdateAdditionalController < WorksWizardController
  before_action :load_work, only: [:update_additional_save, :update_additional]

  # get /works/1/update-additional
  def update_additional
    prepare_decorators_for_work_form(@work)
  end

  # PATCH /works/1/update-additional
  def update_additional_save
    edit_helper(:update_additional, work_readme_select_path(@work))
  end
end
