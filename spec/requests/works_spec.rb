# frozen_string_literal: true
require "rails_helper"

RSpec.describe "/works", type: :request do
  let(:user) { FactoryBot.create :user }

  describe "GET /work" do
    let(:work) do
      FactoryBot.create(:tokamak_work)
    end

    before do
      stub_work_s3_requests(work: work)
    end

    it "will not show a work page unless the user is logged in" do
      get work_url(work)
      expect(response.code).to eq "302"
      redirect_location = response.header["Location"]
      expect(redirect_location).to eq "http://www.example.com/sign_in"
    end

    context "when authenticated" do
      before do
        sign_in(user)
      end

      it "will show the work page displaying the work metadata" do
        get work_url(work)

        expect(response.code).to eq "200"
        expect(response.body).to include("Electron Temperature Gradient Driven Transport Model for Tokamak Plasmas")
      end

      context "when the work does not have a valid collection" do
        let(:work) do
          stubbed = instance_double(Work)
          allow(stubbed).to receive(:s3_object_key).and_return("test-key")
          stubbed
        end

        before do
          allow(work).to receive(:id).and_return("test-id")
          allow(work).to receive(:collection).and_return(nil)
          allow(work).to receive(:attach_s3_resources)

          allow(Work).to receive(:find).and_return(work)
        end

        it "will raise an error" do
          expect { get work_url(work) }.to raise_error(Work::InvalidCollectionError, "The Work test-id does not belong to any Collection")
        end
      end

      context "when the work has been approved" do
        let(:work) { FactoryBot.create(:approved_work) }
        let(:collection) { work.collection }

        context "when appending a second title" do
          let(:params) do
            {
              id: work.id,
              title_main: work.title,
              collection_id: collection.id,
              new_title_1: "the subtitle",
              new_title_type_1: "Subtitle",
              existing_title_count: "1",
              new_title_count: "1",
              given_name_1: "Toni",
              family_name_1: "Morrison",
              sequence_1: "1",
              given_name_2: "Sonia",
              family_name_2: "Sotomayor",
              sequence_2: "1",
              orcid_2: "1234-1234-1234-1234",
              creator_count: "1",
              new_creator_count: "1",
              rights_identifier: "CC BY",
              description: "a new description"
            }
          end

          before do
            patch work_url(work), params: params
          end

          context "when authenticated as a super admin user" do
            let(:user) { FactoryBot.create(:super_admin_user) }

            it "updates the title" do
              expect(response.status).to eq(302)
              work.reload

              expect(work.metadata).to be_a(Hash)
              expect(work.metadata).to include("titles")
              titles = work.metadata["titles"]
              expect(titles.length).to eq(2)

              subtitle = titles.last
              expect(subtitle).to be_a(Hash)
              expect(subtitle).to include("title" => "the subtitle")
              expect(subtitle).to include("title_type" => "Subtitle")
            end
          end

          context "when authenticated as the submitter of the Work" do
            let(:user) { work.created_by_user }

            it "updates the title" do
              expect(response.status).to eq(302)
              work.reload

              expect(work.metadata).to be_a(Hash)
              expect(work.metadata).to include("titles")
              titles = work.metadata["titles"]
              expect(titles.length).to eq(2)

              subtitle = titles.last
              expect(subtitle).to be_a(Hash)
              expect(subtitle).to include("title" => "the subtitle")
              expect(subtitle).to include("title_type" => "Subtitle")
            end
          end

          context "when authenticated as the curator for the Work" do
            let(:user) do
              FactoryBot.create :user, collections_to_admin: [collection]
            end

            it "updates the title" do
              expect(response.status).to eq(302)
              work.reload

              expect(work.metadata).to be_a(Hash)
              expect(work.metadata).to include("titles")
              titles = work.metadata["titles"]
              expect(titles.length).to eq(2)

              subtitle = titles.last
              expect(subtitle).to be_a(Hash)
              expect(subtitle).to include("title" => "the subtitle")
              expect(subtitle).to include("title_type" => "Subtitle")
            end
          end
        end
      end
    end
  end
end
