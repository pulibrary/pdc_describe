# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorksWizardUpdateAdditionalController do
  include ActiveJob::TestHelper
  before do
    stub_ark
    Group.create_defaults
    user
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    # allow(ActiveStorage::PurgeJob).to receive(:new).and_call_original

    stub_request(:get, /#{Regexp.escape('https://example-bucket.s3.amazonaws.com/us_covid_20')}.*\.csv/).to_return(status: 200, body: "", headers: {})
  end

  let(:group) { Group.first }
  let(:curator) { FactoryBot.create(:user, groups_to_admin: [group]) }
  let(:resource) { FactoryBot.build :resource }
  let(:work) { FactoryBot.create(:draft_work, doi: "10.34770/123-abc") }
  let(:user) { work.created_by_user }
  let(:pppl_user) { FactoryBot.create(:pppl_submitter) }

  let(:uploaded_file) { fixture_file_upload("us_covid_2019.csv", "text/csv") }

  context "valid user login" do
    describe "#update_additional_save" do
      let(:params) do
        {
          "title_main" => "test dataset updated",
          "description" => "a new description",
          "group_id" => work.group.id,
          "commit" => "Update Dataset",
          "controller" => "works",
          "action" => "update",
          "id" => work.id.to_s,
          "publisher" => "Princeton University",
          "publication_year" => "2022",
          creators: [{ "orcid" => "", "given_name" => "Jane", "family_name" => "Smith" }]
        }
      end

      it "updates the Work and redirects the readme to select" do
        sign_in user
        patch(:update_additional_save, params:)
        expect(response.status).to be 302
        expect(response.location).to eq "http://test.host/works/#{work.id}/readme-select"
        # expect(ActiveStorage::PurgeJob).not_to have_received(:new)
      end

      context "save and stay on page" do
        let(:stay_params) { params.merge(save_only: true) }

        it "updates the Work and redirects the client to select attachments" do
          sign_in user
          patch(:update_additional_save, params: stay_params)
          expect(response.status).to be 200
          expect(response).to render_template(:update_additional)
        end
      end
    end
  end
end
