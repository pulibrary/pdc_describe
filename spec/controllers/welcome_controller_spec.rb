# frozen_string_literal: true
require "rails_helper"

RSpec.describe WelcomeController do
  it "renders the about page" do
    get :about
    expect(response).to render_template("about")
  end
end
