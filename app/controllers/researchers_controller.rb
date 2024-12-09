# frozen_string_literal: true
class ResearchersController < ApplicationController
  before_action :authenticate_user!

  def ajax_list
    researchers = { suggestions: Researcher.all_researchers}
    render json: researchers.to_json
  end
end
