# frozen_string_literal: true
require "rails_helper"

RSpec.describe "Home Page", type: :request do
  describe "GET /" do
    context "Authenticated user" do
      let(:email) { "pul123@princeton.edu" }
      let(:user) { FactoryBot.create :user, email:, uid: "pul123", given_name: "Toni", full_name: "Toni Morrison" }
      before do
        sign_in user
      end

      it "displays the user's email" do
        get root_path
        expect(response.body.include?("Welcome, Toni")).to be true
      end

      it "displays the user actions menu" do
        get root_path
        expect(response.body.include?("Log Out")).to be true
      end
    end

    context "Unauthenticated user" do
      it "show the login button" do
        get root_path
        expect(response.body.include?("Log In")).to be true
      end

      context "Entra enabled" do
        let(:test_strategy) { Flipflop::FeatureSet.current.test! }

        before do
          test_strategy.switch!(:entra_login, true)
        end
        after do
          test_strategy.switch!(:entra_login, false)
        end

        it "show the login button" do
          get root_path
          expect(response.body.include?("Log In")).to be true
        end
      end
    end
  end
end
