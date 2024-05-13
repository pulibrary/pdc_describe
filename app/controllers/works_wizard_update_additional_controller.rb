# frozen_string_literal: true

require "nokogiri"
require "open-uri"

# Controller to handle the update Additional Metadata step in wizard Mode when editing an work
#
# The wizard flow is shown in the [mermaid diagram here](https://github.com/pulibrary/pdc_describe/blob/main/docs/wizard_flow.md).

class WorksWizardUpdateAdditionalController < WorksWizardController
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
