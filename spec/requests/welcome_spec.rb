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

  # We could replace this demo page and route with a real page once we have more features in the system
  describe "GET /demo" do
    context "Authenticated user" do
      let(:user) { FactoryBot.create :user }
      before do
        sign_in user
      end

      it "displays the page" do
        get "/demo"
        expect(response.body.include?("Authenticated Demo")).to be true
      end
    end
    context "Unauthenticated user" do
      it "redirects the user to the login page" do
        get "/demo"
        expect(response.redirect?).to be true
        expect(response.redirect_url).to eq "http://www.example.com/sign_in"
      end
    end
  end
end
