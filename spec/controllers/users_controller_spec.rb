# frozen_string_literal: true
require "rails_helper"

RSpec.describe UsersController do
  let(:user) { FactoryBot.create(:user) }
  let(:user_other) { FactoryBot.create(:user) }

  it "renders the user dashboard when viewing my own user page" do
    sign_in user
    get :show, params: { id: user.friendly_id }
    expect(response).to render_template("dashboard")
  end

  it "renders the show page when viewing others' users page" do
    sign_in user
    get :show, params: { id: user_other.friendly_id }
    expect(response).to render_template("show")
  end

  describe "#edit" do
    context "when authenticated and the current user is authorized" do
      before do
        sign_in user
      end

      it "renders the edit view" do
        get :edit, params: { id: user.friendly_id }
        expect(response).to render_template("edit")
      end
    end

    context "when authenticated and the current user is not authorized" do
      before do
        sign_in user
      end
      it "logs a warning and redirects the client to the show view" do
        allow(Rails.logger).to receive(:warn)

        get :edit, params: { id: user_other.friendly_id }
        expect(response).to redirect_to(user_path(user_other))
        expect(Rails.logger).to have_received(:warn).with("Unauthorized to edit user #{user_other.id} (current user: #{user.id})")
      end
    end
  end
end
