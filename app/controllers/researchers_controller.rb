# frozen_string_literal: true
class ResearchersController < ApplicationController
  before_action :authenticate_user!

  def ajax_list
    researchers = { suggestions: Researcher.autocomplete_list}
    render json: researchers.to_json
  end

  def index
    @researchers = Researcher.all
  end

end
