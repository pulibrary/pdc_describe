# frozen_string_literal: true
class CreatorsController < ApplicationController
  before_action :authenticate_user!

  def ajax_list
    creators = { suggestions: Creator.all_creators}
    render json: creators.to_json
  end
end