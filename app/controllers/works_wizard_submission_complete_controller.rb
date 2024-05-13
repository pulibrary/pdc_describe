# frozen_string_literal: true

require "nokogiri"
require "open-uri"

# Controller to handle the completion of a submission
#
# The wizard flow is shown in the [mermaid diagram here](https://github.com/pulibrary/pdc_describe/blob/main/docs/wizard_flow.md).
#
class WorksWizardSubmissionCompleteController < ApplicationController
  # get /works/policy
  def show
    @work = Work.find(params[:id])
    @email = if @work.group == Group.plasma_laboratory
               "publications@pppl.gov"
             else
               "prds@princeton.edu"
             end
  end
end
