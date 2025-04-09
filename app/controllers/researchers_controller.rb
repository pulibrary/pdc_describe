# frozen_string_literal: true
class ResearchersController < ApplicationController
  before_action :authenticate_user!

  def ajax_list
    search_term = params["query"] || ""
    researchers = { suggestions: Researcher.autocomplete_list(search_term) }
    render json: researchers.to_json
  end

  def index
    @researchers = Researcher.all
  end
end
