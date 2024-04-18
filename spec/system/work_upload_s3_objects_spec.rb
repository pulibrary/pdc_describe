# frozen_string_literal: true

require "rails_helper"

describe "Uploading S3 Bucket Objects for new Work", mock_ezid_api: true do
  context "when creating a Work" do
    let(:user) { FactoryBot.create :princeton_submitter }
    let(:work) { FactoryBot.create(:shakespeare_and_company_work, created_by_user_id: user.id) }
    let(:s3_query_service_double) { instance_double(S3QueryService, client_s3_files: s3_data) }
    let(:file1) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_README.txt", work: }
    let(:file2) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json", work: }
    let(:fake_s3_service) { stub_s3 }
    let(:filename1) { file1.filename.split("/").last }
    let(:filename2) { file2.filename.split("/").last }
    let(:s3_data) { [file1, file2] }
    let(:bucket_url) do
      "https://example-bucket.s3.amazonaws.com/"
    end

    before do
      sign_in user

      allow(fake_s3_service).to receive(:client_s3_files).and_return(s3_data)
      allow(fake_s3_service).to receive(:file_url).with(file1.key).and_return("https://example-bucket.s3.amazonaws.com/#{file1.key}")
      allow(fake_s3_service).to receive(:file_url).with(file2.key).and_return("https://example-bucket.s3.amazonaws.com/#{file2.key}")

      stub_request(:put, /#{bucket_url}/).to_return(status: 200)
    end

    context "when files are uploaded to the Work as S3 Objects" do
      let(:upload_file_name) do
        "us_covid_2019.csv"
      end
      let(:upload_file) do
        fixture_file_upload(upload_file_name, "text/csv")
      end
      let(:upload_s3_file) { FactoryBot.build :s3_file, filename: "us_covid_2019.csv", work: }

      before do
        work.state = "draft"
        work.save
        work.reload

        stub_request(:delete, /#{bucket_url}/).to_return(status: 200)
        allow(fake_s3_service).to receive(:client_s3_files).and_return(s3_data + [upload_s3_file])
        allow(fake_s3_service).to receive(:file_url).with(upload_s3_file.key).and_return("https://example-bucket.s3.amazonaws.com/#{file1.key}")
      end

      it "renders S3 Bucket Objects and file uploads on the show page", js: true do
        visit work_path(work)
        expect(page).to have_content work.title
        expect(page).to have_content upload_file_name
        expect(page).to have_content filename1
        expect(page).to have_content filename2
        expect(page).to have_content "Total Size\n31.5 KB"
        expect(work.reload.pre_curation_uploads.length).to eq(3)
      end

      it "renders S3 Bucket Objects and file uploads on the edit page", js: true do
        visit work_path(work)
        expect(work.reload.pre_curation_uploads.length).to eq(3)
        visit edit_work_path(work) # can not click Edit link becuase wizard does not show files

        expect(page).to have_content upload_file_name
        expect(page).to have_content filename1
        expect(page).to have_content filename2
      end

      context "when files are deleted from a Work" do
        before do
          allow(fake_s3_service).to receive(:client_s3_files).and_return(s3_data)
          work.save
          work.reload
        end

        it "renders only the S3 Bucket Objects on the show page", js: true do
          visit work_path(work)

          expect(page).to have_content work.title
          expect(page).not_to have_content upload_file_name
          expect(page).to have_content filename1
          expect(page).to have_content filename2
          expect(work.reload.pre_curation_uploads.length).to eq(2)
        end

        it "renders only the S3 Bucket Objects on the edit page", js: true do
          visit work_path(work)
          expect(work.pre_curation_uploads.length).to eq(2)
          visit edit_work_path(work) # can not click Edit link becuase wizard does not show files

          expect(page).not_to have_content upload_file_name
          expect(page).to have_content filename1
          expect(page).to have_content filename2
        end
      end

      context "when the Work is approved" do
        let(:group) { approved_work.group }
        let(:user) { FactoryBot.create(:user, groups_to_admin: [group]) }
        let(:approved_work) { FactoryBot.create(:shakespeare_and_company_work) }
        let(:work) { approved_work } # make sure the id in the file key matches the work

        before do
          allow(fake_s3_service).to receive(:data_profile).and_return({ objects: s3_data, ok: true })
          approved_work.state = "approved"
          approved_work.save
        end

        it "renders S3 Bucket Objects and file uploads on the show page", js: true do
          visit work_path(approved_work)
          expect(page).to have_content approved_work.title

          expect(page).to have_content filename1
          expect(page).to have_content filename2
        end

        it "renders S3 Bucket Objects and file uploads on the edit page", js: true do
          visit work_path(approved_work)
          click_on "Edit"

          expect(page).to have_content filename1
          expect(page).to have_content filename2
        end

        context "when files are deleted from a Work" do
          before do
            approved_work.save
            approved_work.reload
          end

          it "renders only the S3 Bucket Objects on the show page", js: true do
            visit work_path(approved_work)

            expect(page).to have_content approved_work.title
            expect(page).to have_content filename1
            expect(page).to have_content filename2
          end

          it "renders only the S3 Bucket Objects on the edit page", js: true do
            visit work_path(approved_work)
            click_on "Edit"

            expect(page).not_to have_content upload_file_name
            expect(page).to have_content filename1
            expect(page).to have_content filename2
          end
        end
      end
    end
  end
end
