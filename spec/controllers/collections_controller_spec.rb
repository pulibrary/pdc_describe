# frozen_string_literal: true
require "rails_helper"

RSpec.describe CollectionsController do
  before { Collection.create_defaults }
  let(:user) { FactoryBot.create(:user) }

  it "renders the list page" do
    sign_in user
    get :index
    expect(response).to render_template("index")
  end
end
