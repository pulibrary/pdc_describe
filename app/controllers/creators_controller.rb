# frozen_string_literal: true
class CreatorsController < ApplicationController
  before_action :authenticate_user!

  def ajax_list
    creators = { suggestions: [
      { value: 'Claudia', data: 'cl7359' },
      { value: 'Hector', data: 'hc8719' },
      { value: 'Kate', data: 'klynch' },
      { value: 'Jaymee', data: 'jhypolitte' }
    ]
  }
    render json: creators.to_json
  end
end