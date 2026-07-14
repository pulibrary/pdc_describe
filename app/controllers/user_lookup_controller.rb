# frozen_string_literal: true
class UserLookupController < ApplicationController
  def search
    term = params[:term]
    users = User.where("uid ILIKE ?", "#{term}%")
                .or(User.where("family_name ILIKE ?", "#{term}%"))
                .or(User.where("given_name ILIKE ?", "#{term}%"))
                .order(:full_name).limit(20)
    user_data = users.map { |user| { uid: user.uid, name: user.full_name_safe } }
    render json: user_data.to_json
  end
end
