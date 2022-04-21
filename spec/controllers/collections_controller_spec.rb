# frozen_string_literal: true
require "rails_helper"

RSpec.describe CollectionsController do
  let(:user) { FactoryBot.create(:user) }
  let(:user_other) { FactoryBot.create(:user) }

  it "renders the list page" do
    sign_in user
    get :index
    expect(response).to render_template("index")
  end

  # it "renders the show page" do
  #   sign_in user
  #   get :show, params: { id: collection.id }
  #   expect(response).to render_template("show")
  # end
end
