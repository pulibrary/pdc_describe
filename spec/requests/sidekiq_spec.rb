# frozen_string_literal: true
require "rails_helper"
require "sidekiq/testing"

RSpec.describe "Sidekiq Dashboard", type: :request do
  before(:each) do
    # Mock Sidekiq::Web to avoid Redis connection
    allow(Sidekiq::Web).to receive(:call).and_return([200, {}, ["Sidekiq Dashboard"]])
  end

  after(:each) do
    Sidekiq::Testing.disable!
  end
  describe "GET /sidekiq" do
    it "redirects to the sign in page" do
      get "/sidekiq"
      expect(response).to redirect_to(new_user_session_path)
    end
    context "when the user does not have the role sidekiq_admin" do
      let(:user) { create(:external_user) }

      before do
        sign_in user
        get "/sidekiq"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when the user has the role sidekiq_admin" do
      let(:user) { create(:sidekiq_admin_user) }

      before do
        sign_in user
        get "/sidekiq"
      end

      it "allows access to the dashboard" do
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
