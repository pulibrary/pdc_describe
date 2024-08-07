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
  end

  context "a guest cas user" do
    it "redirects to home page with success notice" do
      allow(User).to receive(:from_cas) { FactoryBot.create(:user, uid: "test.user@example.com", email: "test.user@example.com@princeton.edu") }
      get :cas
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Successfully authenticated from Princeton Central Authentication Service account.")
      expect(User.first.email).to eq("test.user@example.com@princeton.edu")
      expect(User.first.uid).to eq("test_user_example_com")
    end
  end

  context "invalid user" do
    it "redirects to home page with warning notice" do
      allow(User).to receive(:from_cas) { nil }
      get :cas
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("You are not authorized")
    end
  end
end
