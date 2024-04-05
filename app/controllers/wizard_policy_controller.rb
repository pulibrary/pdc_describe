# frozen_string_literal: true

require "nokogiri"
require "open-uri"

# Controller to handle the policy agreement acknowlegdement before the wizard is started
#
class WizardPolicyController < ApplicationController
  # get /works/policy
  def show; end

  # post /works/policy
  def update
    group = Group.find_by(code: params[:group_code]) || current_user.default_group
    if params[:agreement] == "1"
      work = Work.create!(created_by_user_id: current_user.id, group:)
      work.add_provenance_note(DateTime.now, "User agreed to the Data Acceptance and Retention policy", current_user.id)
      redirect_to work_create_new_submission_path(work)
    else
      redirect_to root_path, notice: "You must agree to the policy to deposit"
    end
  end
end
