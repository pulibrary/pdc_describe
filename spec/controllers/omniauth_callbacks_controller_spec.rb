# frozen_string_literal: true

require "rails_helper"

RSpec.describe Users::OmniauthCallbacksController do
  before { request.env["devise.mapping"] = Devise.mappings[:user] }

  context "valid user login" do
    it "redirects to home page with success notice" do
      allow(User).to receive(:from_cas) { FactoryBot.create(:user) }
      get :cas
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Successfully authenticated from Princeton Central Authentication Service account.")
    end

    context "entra enabled" do
      let(:test_strategy) { Flipflop::FeatureSet.current.test! }

      before do
        test_strategy.switch!(:entra_login, true)
      end
      after do
        test_strategy.switch!(:entra_login, false)
      end

      it "redirects to home page with success notice" do
        allow(User).to receive(:from_entra) { FactoryBot.create(:user) }
        get :entra_id
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq("Successfully authenticated from Entra ID account.")
      end
    end
  end

  context "a guest user" do
    it "redirects a cas user to home page with success notice" do
      allow(User).to receive(:from_cas) { FactoryBot.create(:user, uid: "test.user@example.com", email: "test.user@example.com@princeton.edu") }
      get :cas
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Successfully authenticated from Princeton Central Authentication Service account.")
      expect(User.first.email).to eq("test.user@example.com@princeton.edu")
      expect(User.first.uid).to eq("test_user_example_com")
    end

    context "entra enabled" do
      let(:test_strategy) { Flipflop::FeatureSet.current.test! }

      before do
        test_strategy.switch!(:entra_login, true)
      end
      after do
        test_strategy.switch!(:entra_login, false)
      end

      it "redirects an entra user to home page with success notice" do
        allow(User).to receive(:from_entra) { FactoryBot.create(:user, uid: "entra_user_id", email: "entra_user@example.com") }
        get :entra_id
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq("Successfully authenticated from Entra ID account.")
        expect(User.first.email).to eq("entra_user@example.com")
        expect(User.first.uid).to eq("entra_user_id")
      end
    end
  end

  describe "GET #failure" do
    around do |example|
      Rails.application.routes.draw do
        get "failure" => "users/omniauth_callbacks#failure"
        get "sign_in" => "welcome#index", as: :new_user_session
      end
      example.run
    ensure
      Rails.application.reload_routes!
    end

    before { allow(Honeybadger).to receive(:notify) }

    it "logs an Entra ID login error to Honeybadger" do
      request.env["omniauth.error.strategy"] = instance_double(OmniAuth::Strategy, name: "entra_id")
      request.env["omniauth.error.type"] = :invalid_credentials
      request.env["omniauth.error"] = StandardError.new("token exchange failed")

      get :failure

      expect(Honeybadger).to have_received(:notify).with(
        "Entra ID login failed: Invalid credentials",
        context: {
          provider: "entra_id",
          error_type: :invalid_credentials,
          error: "token exchange failed"
        }
      )
      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to eq('Could not authenticate you EntraId because "Invalid credentials".')
    end

    it "does not notify Honeybadger for a CAS login failure" do
      request.env["omniauth.error.strategy"] = instance_double(OmniAuth::Strategy, name: "cas")
      request.env["omniauth.error.type"] = :invalid_ticket

      get :failure

      expect(Honeybadger).not_to have_received(:notify)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context "invalid user" do
    it "redirects to home page with warning notice" do
      allow(User).to receive(:from_cas) { nil }
      get :cas
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("You are not authorized")
    end

    context "entra enabled" do
      let(:test_strategy) { Flipflop::FeatureSet.current.test! }

      before do
        test_strategy.switch!(:entra_login, true)
      end
      after do
        test_strategy.switch!(:entra_login, false)
      end

      it "redirects to home page with warning notice" do
        allow(User).to receive(:from_entra) { nil }
        get :entra_id
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq("You are not authorized")
      end
    end
  end
end
