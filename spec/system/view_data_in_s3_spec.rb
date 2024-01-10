# frozen_string_literal: true

require "rails_helper"

RSpec.describe "View status of data in S3", mock_ezid_api: true, js: true do
  before do
    sign_in user
  end

  describe "when a dataset has a DOI and its data is in S3" do
    let(:user) { FactoryBot.create :princeton_submitter }
    let(:work) { FactoryBot.create(:shakespeare_and_company_work, created_by_user_id: user.id) }
    let(:s3_query_service_double) { instance_double(S3QueryService) }
    let(:file1) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_datafile.txt", work: }
    let(:file2) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json", work: }
    let(:file3) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/something_README.txt", work: }
    let(:s3_data) { [file1, file2, file3] }

    let(:bucket_url) do
      "https://example-bucket.s3.amazonaws.com/"
    end

    it "shows data from S3 on the Show and Edit pages" do
      stub_s3(data: s3_data)

      work.save
      work.reload
      work.state = "awaiting_approval"
      work.save

      visit work_path(work)
      expect(page).to have_content work.title
      expect(page).to have_content file1.filename_display
      expect(page).to have_content file2.filename_display

      click_on "Edit"
      expect(page).to have_content file1.filename_display
      expect(page).to have_content file2.filename_display
    end

    it "uses DataTable to display files" do
      stub_s3(data: s3_data)

      work.save

      visit work_path(work)
      # DataTables is active
      expect(page.has_content?(/Showing 1 to [0-9]+ of [0-9]+ entries/)).to be true
      # and file are rendered as links pointing to the download endpoint
      expect(page.body.include?("download?filename=#{file2.filename}"))
      # and we rendered the date in the display format
      expect(page.body.include?(s3_data.first.last_modified_display))
      # make sure that the README file shows first in the data table
      readme_css_selector = '#files-table>tbody>tr:first-child>td>span>a[href="' + work.id.to_s + '/download?filename=10.34770/pe9w-x904/1/something_README.txt"]'
      expect(page.has_selector?(readme_css_selector)).to be true
    end

    context "when item is approved" do
      let(:work) { FactoryBot.create(:approved_work) }
      it "shows data from S3" do
        stub_s3(data: [file1])

        visit work_path(work)
        expect(page).to have_link file1.filename_display, href: "#{work.id}/download?filename=#{file1.filename}"
        expect(find_link(file1.filename_display)[:target]).to eq("_blank")
        expect(page).not_to have_button("Edit")
      end

      context "when user is a curator" do
        let(:user) { FactoryBot.create(:research_data_moderator) }
        it "shows data from S3" do
          stub_s3(data: s3_data)
          visit work_path(work)
          expect(page).to have_link file1.filename_display, href: "#{work.id}/download?filename=#{file1.filename}"
          expect(page).to have_link file2.filename_display, href: "#{work.id}/download?filename=#{file2.filename}"

          click_on "Edit"
          expect(page).to have_link file1.filename_display, href: "#{work.id}/download?filename=#{file1.filename}"
          expect(page).to have_link file2.filename_display, href: "#{work.id}/download?filename=#{file2.filename}"
        end
      end

      context "when user is a super admin user" do
        let(:user) { FactoryBot.create(:research_data_moderator) }
        it "shows data from S3" do
          stub_s3(data: s3_data)
          visit work_path(work)
          expect(page).to have_link file1.filename_display, href: "#{work.id}/download?filename=#{file1.filename}"
          expect(page).to have_link file2.filename_display, href: "#{work.id}/download?filename=#{file2.filename}"

          click_on "Edit"
          expect(page).to have_link file1.filename_display, href: "#{work.id}/download?filename=#{file1.filename}"
          expect(page).to have_link file2.filename_display, href: "#{work.id}/download?filename=#{file2.filename}"
        end
      end
    end
  end
end
