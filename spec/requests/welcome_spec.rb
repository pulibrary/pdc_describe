# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Home Page", type: :request do
  describe "GET /" do
    context "Authenticated user" do
      let(:email) { "pul123@princeton.edu" }
      let(:user) { FactoryBot.create :user, email: email }
      before do
        sign_in user
      end

      it "displays the user's email" do
        get root_path
        expect(response.body.include?(email)).to be true
      end
    end

    context "Unauthenticated user" do
      it "show the login button" do
        get root_path
        expect(response.body.include?("Login")).to be true
      end
    end
  end
end
