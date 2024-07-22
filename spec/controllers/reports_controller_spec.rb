# frozen_string_literal: true
require "rails_helper"

RSpec.describe ReportsController do
  let(:user) { FactoryBot.create(:user) }
  let(:moderator) { FactoryBot.create(:pppl_moderator) }
  let(:group) { FactoryBot.create(:group) }

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

  it "renders reports with group, year, and \"finished\" status" do
    sign_in moderator
    get :dataset_list, params: { status: "finished", group: :group["code"], year: 2020 }
    expect(response).to render_template("dataset_list")
  end

  it "renders reports with group, year, and \"unfinished\" status" do
    sign_in moderator
    get :dataset_list, params: { status: "unfinished", group: :group["code"], year: 2021 }
    expect(response).to render_template("dataset_list")
  end
end
