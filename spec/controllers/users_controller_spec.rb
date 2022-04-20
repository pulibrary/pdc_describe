# frozen_string_literal: true
require "rails_helper"

RSpec.describe UsersController do
  let(:user) { FactoryBot.create(:user) }
  let(:user_other) { FactoryBot.create(:user) }

  it "renders the user dashboard when viewing my own user page" do
    sign_in user
    get :show, params: { id: user.id }
    expect(response).to render_template("dashboard")
  end

  it "renders the show page when viewing others' users page" do
    sign_in user
    get :show, params: { id: user_other.id }
    expect(response).to render_template("show")
  end
end
