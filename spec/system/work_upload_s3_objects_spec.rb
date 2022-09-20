# frozen_string_literal: true

require "rails_helper"

describe "Uploading S3 Bucket Objects for new Work", mock_ezid_api: true do
  context "when creating a Work", mock_s3_query_service: false do
    let(:user) { FactoryBot.create :princeton_submitter }
    let(:work) { FactoryBot.create(:shakespeare_and_company_work) }
    let(:s3_query_service_double) { instance_double(S3QueryService) }
    let(:file1) do
      S3File.new(
        filename: "SCoData_combined_v1_2020-07_README.txt",
        last_modified: Time.parse("2022-04-21T18:29:40.000Z"),
        size: 10_759,
        checksum: "abc123"
      )
    end
    let(:file2) do
      S3File.new(
        filename: "SCoData_combined_v1_2020-07_datapackage.json",
        last_modified: Time.parse("2022-04-21T18:30:07.000Z"),
        size: 12_739,
        checksum: "abc567"
      )
    end
    let(:s3_data) { [file1, file2] }
    let(:bucket_url) do
      "https://example-bucket.s3.amazonaws.com/"
    end

    before do
      sign_in user

      # Account for files in S3 added outside of ActiveStorage
      allow(S3QueryService).to receive(:new).and_return(s3_query_service_double)
      allow(s3_query_service_double).to receive(:data_profile).and_return({ objects: s3_data, ok: true })
      # Account for files uploaded to S3 via ActiveStorage
      stub_request(:put, /#{bucket_url}/).to_return(status: 200)
    end

    context "when files are uploaded to the Work as S3 Objects" do
      let(:upload_file_name) do
        "us_covid_2019.csv"
      end
      let(:upload_file) do
        fixture_file_upload(upload_file_name, "text/csv")
      end

      before do
        work.pre_curation_uploads.attach(upload_file)
        work.save
        work.reload
        work.save

        stub_request(:delete, /#{bucket_url}/).to_return(status: 200)
      end

      after do
        work.pre_curation_uploads.map(&:purge)
        work.save
      end

      it "renders S3 Bucket Objects and file uploads on the show page", js: true do
        expect(work.pre_curation_uploads.length).to eq(3)
        visit work_path(work)
        expect(page).to have_content work.title

        expect(page).to have_content upload_file_name
        expect(page).to have_content file1.filename
        expect(page).to have_content file2.filename
      end

      it "renders S3 Bucket Objects and file uploads on the edit page", js: true do
        expect(work.pre_curation_uploads.length).to eq(3)
        visit work_path(work)
        click_on "Edit"

        expect(page).to have_content upload_file_name
        expect(page).to have_content file1.filename
      end

      context "when files are deleted from a Work" do
        before do
          attachments = work.pre_curation_uploads.select { |e| e.filename.to_s == upload_file_name }
          attachments.each(&:purge)
          work.save
          work.reload
        end

        it "renders only the S3 Bucket Objects on the show page", js: true do
          expect(work.pre_curation_uploads.length).to eq(2)
          visit work_path(work)

          expect(page).to have_content work.title
          expect(page).to have_content file1.filename
          expect(page).to have_content file2.filename
        end

        it "renders only the S3 Bucket Objects on the edit page", js: true do
          expect(work.pre_curation_uploads.length).to eq(2)
          visit work_path(work)
          click_on "Edit"

          expect(page).not_to have_content upload_file_name
          expect(page).to have_content file1.filename
        end
      end

      context "when the Work is approved" do
        let(:collection) { approved_work.collection }
        let(:user) { FactoryBot.create(:user, collections_to_admin: [collection]) }
        let(:approved_work) { FactoryBot.create(:shakespeare_and_company_work) }

        before do
          approved_work.pre_curation_uploads.attach(upload_file)
          approved_work.save
          approved_work.reload
          approved_work.state = "accepted"
          approved_work.save
        end

        it "renders S3 Bucket Objects and file uploads on the show page", js: true do
          visit work_path(approved_work)
          expect(page).to have_content approved_work.title

          expect(page).to have_content upload_file_name
          expect(page).to have_content file1.filename
          expect(page).to have_content file2.filename
        end

        it "renders S3 Bucket Objects and file uploads on the edit page", js: true do
          visit work_path(approved_work)
          click_on "Edit"

          expect(page).to have_content upload_file_name
          expect(page).to have_content file1.filename
          expect(page).to have_content file2.filename
        end

        context "when files are deleted from a Work" do
          before do
            attachments = approved_work.pre_curation_uploads.select { |e| e.filename.to_s == upload_file_name }
            attachments.each(&:purge)
            approved_work.save
            approved_work.reload
          end

          it "renders only the S3 Bucket Objects on the show page", js: true do
            expect(approved_work.pre_curation_uploads.length).to eq(2)
            visit work_path(approved_work)

            expect(page).to have_content approved_work.title
            expect(page).to have_content file1.filename
            expect(page).to have_content file2.filename
          end

          it "renders only the S3 Bucket Objects on the edit page", js: true do
            expect(approved_work.pre_curation_uploads.length).to eq(2)
            visit work_path(approved_work)
            click_on "Edit"

            expect(page).not_to have_content upload_file_name
            expect(page).to have_content file1.filename
            expect(page).to have_content file2.filename
          end
        end
      end
    end
  end
end
