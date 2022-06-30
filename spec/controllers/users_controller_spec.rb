# frozen_string_literal: true
require "rails_helper"

RSpec.describe UsersController do
  let(:user) { FactoryBot.create(:user) }
  let(:user_other) { FactoryBot.create(:user) }

  it "renders the show page" do
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

  describe "#update" do
    let(:email) { "user@localhost.localdomain" }
    let(:params) do
      {
        id: user.friendly_id,
        user: {
          email: email
        },
        format: format
      }
    end

    context "when authenticated" do
      context "when requesting a HTML representation" do
        let(:format) { :html }

        context "when the update fails" do
          before do
            sign_in user
            allow_any_instance_of(User).to receive(:update).and_return(false)
            patch :update, params: params
          end

          it "renders the edit view with a 422 response status code" do
            expect(response.code).to eq("422")
            expect(response).to render_template(:edit)
          end
        end
      end

      context "when requesting a JSON representation" do
        let(:format) { :json }

        context "when the update fails" do
          before do
            sign_in user
            allow_any_instance_of(User).to receive(:update).and_return(false)
            patch :update, params: params
          end

          it "renders JSON-serialized error messages with a 422 response status code" do
            expect(response.code).to eq("422")
          end
        end
      end
    end

    context "when authenticated with an unauthorized" do
      let(:format) { :html }
      before do
        allow(Rails.logger).to receive(:warn)
        sign_in user_other
        patch :update, params: params
      end

      it "renders the edit view with a 422 response status code" do
        expect(response).to redirect_to(user_path(user))
        expect(Rails.logger).to have_received(:warn).with("Unauthorized to update user #{user.id} (current user: #{user_other.id})")
      end
    end
  end
end
