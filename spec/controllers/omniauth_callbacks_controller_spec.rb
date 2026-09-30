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
