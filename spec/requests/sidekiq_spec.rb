# frozen_string_literal: true
require "rails_helper"
require "sidekiq/testing"

RSpec.describe "Sidekiq Dashboard", type: :request do
  before(:each) do
    # Mock Sidekiq::Web to avoid Redis connection
    allow(Sidekiq::Web).to receive(:call).and_return([200, {}, ["Sidekiq Dashboard"]])
  end

  after(:each) do
    allow(Sidekiq::Web).to receive(:call).and_call_original
  end

  describe "GET /sidekiq" do
    context "when the client is not authenticated" do
      it "redirects to the sign in page" do
        get sidekiq_web_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when the user does not have the role sidekiq_admin" do
      let(:user) { create(:external_user) }

      before do
        sign_in user
      end

      it "responds with a 404 (not found) HTTP response" do
        get sidekiq_web_path
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the user has the role sidekiq_admin" do
      let(:user) { create(:sidekiq_admin_user) }

      before do
        sign_in user
        get sidekiq_web_path
      end

      it "allows access to the dashboard" do
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
