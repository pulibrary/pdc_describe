# frozen_string_literal: true
require "rails_helper"

RSpec.describe ReportsController do
  let(:user) { FactoryBot.create(:user) }
  let(:moderator) { FactoryBot.create(:pppl_moderator) }
  it "renders the reports" do
    sign_in moderator
    get :dataset_list
    expect(response).to render_template("dataset_list")
  end

  
  it "redirects user to the homepage" do
    sign_in user
    get :dataset_list
    expect(response).to redirect_to("/")
  end
end
