# frozen_string_literal: true
require "rails_helper"

RSpec.describe Work, type: :model, mock_ezid_api: true do
  let(:user) { FactoryBot.create :user }
  let(:collection) { Collection.research_data }
  let(:user_other) { FactoryBot.create :user }
  let(:super_admin_user) { FactoryBot.create :super_admin_user }
  let(:work) { FactoryBot.create(:draft_work) }
  let(:work2) { FactoryBot.create(:draft_work) }

  let(:rd_user) { FactoryBot.create :princeton_submitter }

  let(:pppl_user) { FactoryBot.create :pppl_submitter }

  let(:curator_user) do
    FactoryBot.create :user, collections_to_admin: [Collection.research_data]
  end

  # Please see spec/support/ezid_specs.rb
  let(:ezid) { @ezid }
  let(:identifier) { @identifier }
  let(:attachment_url) { /#{Regexp.escape("https://example-bucket.s3.amazonaws.com/")}/ }

  before do
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
  end

  it "checks the format of the ORCID of the creators" do
    # Add a new creator with an incomplete ORCID
    work.resource.creators << PDCMetadata::Creator.new_person("Williams", "Serena", "1234-12")
    expect(work.save).to be false
    expect(work.errors.find { |error| error.type.include?("ORCID") }).to be_present
  end

  it "drafts a doi only once" do
    work = Work.new(collection: collection, resource: FactoryBot.build(:resource))
    work.draft_doi
    work.draft_doi # Doing this multiple times on purpose to make sure the api is only called once
    expect(a_request(:post, ENV["DATACITE_URL"])).to have_been_made.once
  end

  it "prevents datasets with no users" do
    work = Work.new(collection: collection, resource: PDCMetadata::Resource.new)
    expect { work.draft! }.to raise_error AASM::InvalidTransition
  end

  it "prevents datasets with no collections" do
    work = Work.new(collection: nil, resource: FactoryBot.build(:resource))
    expect { work.save! }.to raise_error ActiveRecord::RecordInvalid
  end

  describe "#editable_by?" do
    subject(:work) { FactoryBot.create(:tokamak_work) }
    let(:submitter) { work.created_by_user }
    let(:other_user) { FactoryBot.create(:princeton_submitter) }
    let(:pppl_moderator) { FactoryBot.create(:pppl_moderator) }
    let(:research_data_moderator) { FactoryBot.create(:research_data_moderator) }
    let(:super_admin) { FactoryBot.create(:super_admin_user) }

    it "is editable by the user who made it" do
      expect(work.editable_by?(submitter)).to eq true
    end

    it "is editable by collection admins of its collection" do
      expect(work.editable_by?(pppl_moderator)).to eq true
    end

    it "is editable by super admins" do
      expect(work.editable_by?(super_admin)).to eq true
    end

    it "is not editable by another user" do
      expect(work.editable_by?(other_user)).to eq false
    end

    it "is not editable by a collection admin of a different collection" do
      expect(work.editable_by?(research_data_moderator)).to eq false
    end
  end

  context "with a persisted dataset work" do
    subject(:work) { FactoryBot.create(:draft_work) }

    let(:uploaded_file) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end
    let(:uploaded_file2) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end

    before do
      stub_request(:put, /#{attachment_url}/).with(
        body: "date,state,fips,cases,deaths\n2020-01-21,Washington,53,1,0\n2022-07-10,Wyoming,56,165619,1834\n"
      ).to_return(status: 200)

      20.times { work.pre_curation_uploads.attach(uploaded_file) }
      work.save!
    end

    it "prevents works from having more than 20 uploads attached" do
      work.pre_curation_uploads.attach(uploaded_file2)

      expect { work.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Only 20 files may be uploaded by a user to a given Work. 21 files were uploaded for the Work: #{work.ark}")

      persisted = described_class.find(work.id)
      expect(persisted.pre_curation_uploads.length).to eq(20)
    end
  end

  it "approves works and records the change history" do
    stub_datacite_doi
    work.complete_submission!(user)
    work.approve!(curator_user)
    expect(work.state_history.first.state).to eq "approved"
    expect(work.reload.state).to eq("approved")
  end

  it "withdraw works and records the change history" do
    work.withdraw!(user)
    expect(work.state_history.first.state).to eq "withdrawn"
    expect(work.reload.state).to eq("withdrawn")
  end

  it "resubmit works and records the change history" do
    work.withdraw!(user)
    work.resubmit!(user)
    expect(work.state_history.first.state).to eq "draft"
    expect(work.reload.state).to eq("draft")
  end

  it "does not allow direct asignment to the metadata" do
    expect { work.metadata = "abc" }.to raise_error NoMethodError
  end

  context "ARK update" do
    before { allow(Ark).to receive(:update) }
    let(:ezid) { "ark:/99999/dsp01qb98mj541" }

    around do |example|
      Rails.configuration.update_ark_url = true
      example.run
      Rails.configuration.update_ark_url = false
    end

    it "updates the ARK metadata" do
      work.resource.ark = ezid
      work.save
      work.complete_submission!(user)
      stub_datacite_doi
      work.approve!(curator_user)
      expect(Ark).to have_received(:update).exactly(1).times
    end

    it "does not update the ARK metadata" do
      work.resource.ark = nil
      work.save
      work.complete_submission!(user)
      stub_datacite_doi
      work.approve!(curator_user)
      expect(Ark).to have_received(:update).exactly(0).times
    end
  end

  describe "#created_by_user" do
    context "when the ID is invalid" do
      subject(:work) { FactoryBot.create(:draft_work) }
      let(:title) { "test title" }
      let(:user_id) { user.id }
      let(:collection_id) { collection.id }

      before do
        allow(User).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
      end

      it "returns a nil" do
        expect(work.created_by_user).to be nil
      end
    end
  end

  context "when created with an existing ARK" do
    context "and when the ARK is valid" do
      let(:ezid) { "ark:/99999/dsp01qb98mj541" }

      around do |example|
        Rails.configuration.update_ark_url = true
        example.run
        Rails.configuration.update_ark_url = false
      end

      it "does not mint a new ARK" do
        expect(work.persisted?).not_to be false
        work.resource.ark = ezid
        work.save

        expect(work.persisted?).to be true
        expect(work.ark).to eq(ezid)
      end
    end

    context "and when the ARK is invalid" do
      before do
        # The HTTP call to EZID will fail because the id is invalid
        allow(Ezid::Identifier).to receive(:find).and_raise(Net::HTTPServerException, '400 "Bad Request"')
      end

      it "raises an error" do
        expect(work.persisted?).not_to be false
        bad_ezid = "ark:/bad-99999/fk4tq65d6k"
        work.resource.ark = bad_ezid
        expect { work.save! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Invalid ARK provided for the Work: #{bad_ezid}")
      end
    end
  end

  context "linked to a work" do
    let(:work) { FactoryBot.create(:shakespeare_and_company_work) }
    it "has a DOI" do
      expect(work.title).to eq "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events"
      expect(work.resource.doi).to eq "https://doi.org/10.34770/pe9w-x904"
    end
  end

  describe "datasets waiting for approval by user type" do
    before do
      FactoryBot.create(:draft_work, created_by_user_id: user.id)
      FactoryBot.create(:draft_work, created_by_user_id: user.id)
      FactoryBot.create(:draft_work, created_by_user_id: pppl_user.id, collection_id: Collection.plasma_laboratory.id)
      # Create the dataset for `rd_user` and @mention `user`
      ds = FactoryBot.create(:draft_work, created_by_user_id: rd_user.id)
      WorkActivity.add_system_activity(ds.id, "Tagging @#{user.uid} in this dataset", rd_user.id)
    end

    it "for a typical user retrieves only the datasets created by the user or where the user is tagged" do
      user_datasets = described_class.unfinished_works(user)
      expect(user_datasets.count).to be 3
      expect(user_datasets.count { |ds| ds.created_by_user_id == user.id }).to be 2
      expect(user_datasets.count { |ds| ds.created_by_user_id == rd_user.id }).to be 1
    end

    it "for a curator retrieves dataset created in collections they can curate" do
      expect(described_class.unfinished_works(curator_user).length).to eq(3)
    end

    it "for super_admins retrieves for all collections" do
      expect(described_class.unfinished_works(super_admin_user).length).to eq(4)
    end
  end

  describe "#change_curator" do
    it "changes the curator and the logs changes" do
      expect(work.curator).to be nil

      work.change_curator(curator_user.id, user)
      activity = work.activities.find { |a| a.message.include?("Set curator to @#{curator_user.uid}") }
      expect(work.curator.id).to be curator_user.id
      expect(activity.created_by_user.id).to eq user.id

      work.change_curator(user.id, user)
      activity = work.activities.find { |a| a.message.include?("Self-assigned as curator") }
      expect(work.curator.id).to be user.id
      expect(activity.created_by_user.id).to eq user.id

      work.clear_curator(user)
      activity = work.activities.find { |a| a.message.include?("Unassigned existing curator") }
      expect(work.curator).to be nil
      expect(activity.created_by_user.id).to eq user.id
    end
  end

  describe "#add_comment" do
    it "adds a comment" do
      work.add_comment("hello world", user)
      activity = work.activities.find { |a| a.message.include?("hello world") }
      expect(activity.created_by_user.id).to eq user.id
      expect(activity.activity_type).to eq "COMMENT"
    end

    it "logs notifications" do
      expect(work.new_notification_count_for_user(user.id)).to eq 0
      expect(work.new_notification_count_for_user(curator_user.id)).to eq 0

      work.add_comment("taggging @#{curator_user.uid}", user)
      work2.add_comment("taggging @#{curator_user.uid}", user)
      expect(work.new_notification_count_for_user(user.id)).to eq 0
      expect(work.new_notification_count_for_user(curator_user.id)).to eq 1

      work.mark_new_notifications_as_read(curator_user.id)
      expect(work.new_notification_count_for_user(curator_user.id)).to eq 0
    end

    it "parses tagged users correctly" do
      message = "taggging @#{curator_user.uid} and @#{user_other.uid}"
      work.add_comment(message, user)
      activity = work.activities.find { |a| a.message.include?(message) }
      expect(activity.message_html.include?("#{curator_user.uid}</a>")).to be true
      expect(activity.message_html.include?("#{user_other.uid}</a>")).to be true
    end
  end

  describe "#pre_curation_uploads" do
    let(:uploaded_file) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end

    let(:uploaded_file2) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end

    before do
      stub_request(:put, /#{attachment_url}/).with(
        body: "date,state,fips,cases,deaths\n2020-01-21,Washington,53,1,0\n2022-07-10,Wyoming,56,165619,1834\n"
      ).to_return(status: 200)

      work.pre_curation_uploads.attach(uploaded_file)
      work.save
    end

    context "with configured to use the human-readable storage service", humanizable_storage: true do
      it "attaches deposited file uploads to the Work model with human-readable file paths" do
        expect(work.pre_curation_uploads).not_to be_empty

        attached = work.pre_curation_uploads.first
        expect(attached).to be_a(ActiveStorage::Attachment)
        expect(attached.blob).to be_a(ActiveStorage::Blob)
        expect(attached.blob.key).to eq("#{work.doi}/#{work.id}/us_covid_2019.csv")
        local_disk_path = Rails.root.join("spec", "fixtures", "storage", work.doi, work.id.to_s, "us_covid_2019.csv")
        expect(File.exist?(local_disk_path)).to be true

        work.pre_curation_uploads.attach(uploaded_file2)
        attached2 = work.pre_curation_uploads.last
        expect(attached2).to be_a(ActiveStorage::Attachment)
        expect(attached2.blob).to be_a(ActiveStorage::Blob)
        expect(attached2.blob.key).to eq("#{work.doi}/#{work.id}/us_covid_2019_2.csv")
        local_disk_path = Rails.root.join("spec", "fixtures", "storage", work.doi, work.id.to_s, "us_covid_2019_2.csv")
        expect(File.exist?(local_disk_path)).to be true

        work2.pre_curation_uploads.attach(uploaded_file)
        attached = work2.pre_curation_uploads.first
        expect(attached).to be_a(ActiveStorage::Attachment)
        expect(attached.blob).to be_a(ActiveStorage::Blob)
        expect(attached.blob.key).to eq("#{work2.doi}/#{work2.id}/us_covid_2019.csv")
        local_disk_path = Rails.root.join("spec", "fixtures", "storage", work2.doi, work2.id.to_s, "us_covid_2019.csv")
        expect(File.exist?(local_disk_path)).to be true
      end
    end
  end

  describe "#draft" do
    let(:draft_work) do
      work = Work.new(collection: collection, resource: FactoryBot.build(:resource))
      work.draft!(user)
      work = Work.find(work.id)
      work
    end

    it "transitions from none to draft" do
      expect(draft_work.reload.state).to eq("draft")
    end

    it "drafts a doi and the DOI is persisted" do
      draft_work
      expect(a_request(:post, ENV["DATACITE_URL"])).to have_been_made
      expect(draft_work.resource.doi).not_to eq nil
    end

    it "transitions from draft to withdrawn" do
      draft_work.withdraw!(user)
      expect(draft_work.reload.state).to eq("withdrawn")
    end

    it "can not transition from draft to approved" do
      expect { draft_work.approve!(curator_user) }.to raise_error AASM::InvalidTransition
    end

    it "can not transition from draft to tombsotne" do
      expect { draft_work.remove!(user) }.to raise_error AASM::InvalidTransition
    end
  end

  describe "#complete_submission" do
    let(:awaiting_approval_work) do
      work = FactoryBot.create :draft_work
      work.complete_submission!(user)
      work
    end

    it "is awaiting approval" do
      expect(awaiting_approval_work.reload.state).to eq("awaiting_approval")
    end

    it "transitions from awaiting_approval to withdrawn" do
      awaiting_approval_work.withdraw!(user)
      expect(awaiting_approval_work.reload.state).to eq("withdrawn")
    end

    it "transitions from awaiting_approval to approved" do
      stub_datacite_doi
      awaiting_approval_work.approve!(curator_user)
      expect(awaiting_approval_work.reload.state).to eq("approved")
    end

    context "submitter user" do
      let(:user) { FactoryBot.create(:princeton_submitter) }

      it "can not transition from awaitng_approval to approved" do
        expect { awaiting_approval_work.approve!(user) }.to raise_error AASM::InvalidTransition
        expect(awaiting_approval_work.reload.state).to eq("awaiting_approval")
      end
    end

    it "can not transition from awaiting_approval to tombsotne" do
      expect { awaiting_approval_work.remove!(user) }.to raise_error AASM::InvalidTransition
    end

    it "can not transition from awaiting_approval to draft" do
      expect { awaiting_approval_work.draft!(user) }.to raise_error AASM::InvalidTransition
    end
  end

  describe "#approve" do
    let(:approved_work) do
      work = FactoryBot.create :draft_work
      work.complete_submission!(user)
      work.approve!(curator_user)
      work
    end

    it "is approved" do
      stub_datacite_doi
      expect(approved_work.reload.state).to eq("approved")
    end

    it "publishes the doi" do
      stub_request(:put, "https://api.datacite.org/dois/https://doi.org/10.34770/123-abc")
      expect { approved_work }.to change { WorkActivity.where(activity_type: "DATACITE_ERROR").count }.by(0)
      expect(a_request(:put, "https://api.datacite.org/dois/https://doi.org/10.34770/123-abc")).to have_been_made
    end

    it "notes a issue when an error occurs" do
      stub_datacite_doi(result: Failure(Faraday::Response.new(Faraday::Env.new(status: "bad", reason_phrase: "a problem"))))
      expect { approved_work }.to change { WorkActivity.where(activity_type: "DATACITE_ERROR").count }.by(1)
    end

    it "transitions from approved to withdrawn" do
      stub_datacite_doi
      approved_work.withdraw!(user)
      expect(approved_work.reload.state).to eq("withdrawn")
    end

    it "can not transition from approved to tombsotne" do
      stub_datacite_doi
      expect { approved_work.remove!(user) }.to raise_error AASM::InvalidTransition
    end

    it "can not transition from approved to awaiting_approval" do
      stub_datacite_doi
      expect { approved_work.complete_submission!(user) }.to raise_error AASM::InvalidTransition
    end

    it "can not transition from approved to draft" do
      stub_datacite_doi
      expect { approved_work.draft!(user) }.to raise_error AASM::InvalidTransition
    end
  end

  describe "#withraw" do
    let(:withdrawn_work) do
      work = FactoryBot.create :draft_work
      work.withdraw!(user)
      work
    end

    it "is withdrawn" do
      expect(withdrawn_work.reload.state).to eq("withdrawn")
    end

    it "transitions from withdrawn to draft" do
      withdrawn_work.resubmit!(user)
      expect(withdrawn_work.reload.state).to eq("draft")
    end

    it "transitions from withdrawn to tombstone" do
      withdrawn_work.remove!(user)
      expect(withdrawn_work.reload.state).to eq("tombstone")
    end

    it "can not transition from withdrawn to approved" do
      expect { withdrawn_work.approve!(user) }.to raise_error AASM::InvalidTransition
    end

    it "can not transition from withdrawn to awaiting_approval" do
      expect { withdrawn_work.complete_submission!(user) }.to raise_error AASM::InvalidTransition
    end

    it "can not transition from withdrawn to draft" do
      expect { withdrawn_work.draft!(user) }.to raise_error AASM::InvalidTransition
    end
  end

  describe "#remove" do
    let(:removed_work) do
      work = FactoryBot.create :draft_work
      work.withdraw!(user)
      work.remove!(user)
      work
    end

    it "is tombstoned" do
      expect(removed_work.reload.state).to eq("tombstone")
    end

    it "can not transition from tombstone to approved" do
      expect { removed_work.approve!(user) }.to raise_error AASM::InvalidTransition
    end

    it "can not transition from tombstone to awaiting_approval" do
      expect { removed_work.complete_submission!(user) }.to raise_error AASM::InvalidTransition
    end

    it "can not transition from tombstone to draft" do
      expect { removed_work.draft!(user) }.to raise_error AASM::InvalidTransition
    end
  end

  describe "states" do
    let(:work) { Work.new(collection: collection, resource: FactoryBot.build(:resource)) }
    it "initally is none" do
      expect(work.none?).to be_truthy
      expect(work.state).to eq("none")
    end

    it "can not be removed from none" do
      expect { work.remove!(user) }.to raise_error AASM::InvalidTransition
    end

    it "can not be approved from none" do
      expect { work.approve!(curator_user) }.to raise_error AASM::InvalidTransition
    end

    it "can not be maked ready for review from none" do
      expect { work.complete_submission!(user) }.to raise_error AASM::InvalidTransition
    end

    it "can not be withdrawn from none" do
      expect { work.withdraw!(user) }.to raise_error AASM::InvalidTransition
    end
  end

  describe "#add_attachment" do
    let(:key) { "10.34770/tbd/6/Screen Shot 2022-08-23 at 4.20.40 PM.png" }
    let(:size) { 10_759 }
    let(:etag) { "1a3cc96aa01110fcb04d3227c9cbae9e" }
    let(:s3_file) do
      S3File.new(filename: key,
                 last_modified: Time.parse("2022-04-21T18:29:40.000Z"),
                 size: size,
                 checksum: etag)
    end

    it "adds an s3 attachment" do
      work.add_pre_curation_uploads(s3_file)
      expect(work.pre_curation_uploads.count).to eq(1)
      expect(work.pre_curation_uploads.first.key).to eq(key)
    end
  end

  describe "#save", mock_s3_query_service: false do
    context "when the Work is persisted and not yet in the approved state" do
      let(:work) { FactoryBot.create(:draft_work) }

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
        # Account for files in S3 added outside of ActiveStorage
        allow(S3QueryService).to receive(:new).and_return(s3_query_service_double)
        allow(s3_query_service_double).to receive(:data_profile).and_return({ objects: s3_data, ok: true })
        # Account for files uploaded to S3 via ActiveStorage
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)

        work.complete_submission!(user)
        work.reload
      end

      it "persists S3 Bucket resources as ActiveStorage Attachments" do
        expect(work.pre_curation_uploads).not_to be_empty
        expect(work.pre_curation_uploads.length).to eq(2)
        expect(work.pre_curation_uploads.first).to be_a(ActiveStorage::Attachment)
        expect(work.pre_curation_uploads.first.key).to eq("SCoData_combined_v1_2020-07_README.txt")
        expect(work.pre_curation_uploads.last).to be_a(ActiveStorage::Attachment)
        expect(work.pre_curation_uploads.last.key).to eq("SCoData_combined_v1_2020-07_datapackage.json")
      end

      context "a blob already exists for one of the files" do
        let(:work) do
          work = FactoryBot.create(:draft_work)
          blob = work.send(:s3_file_to_blob, file1)
          blob.save
          work.save
          work
        end

        it "finds the blob and attaches it as an ActiveStorage Attachments" do
          expect(work.pre_curation_uploads).not_to be_empty
          expect(work.pre_curation_uploads.length).to eq(2)
          expect(work.pre_curation_uploads.first).to be_a(ActiveStorage::Attachment)
          expect(work.pre_curation_uploads.first.key).to eq("SCoData_combined_v1_2020-07_README.txt")
          expect(work.pre_curation_uploads.last).to be_a(ActiveStorage::Attachment)
          expect(work.pre_curation_uploads.last.key).to eq("SCoData_combined_v1_2020-07_datapackage.json")
        end
      end
    end
  end

  describe "#form_attributes" do
    let(:uploaded_file) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end
    let(:form_attributes) { work.form_attributes }

    before do
      stub_request(:put, /#{attachment_url}/).with(
        body: "date,state,fips,cases,deaths\n2020-01-21,Washington,53,1,0\n2022-07-10,Wyoming,56,165619,1834\n"
      ).to_return(status: 200)

      work.pre_curation_uploads.attach(uploaded_file)
      work.save
    end

    it "generates JSON properties for each attribute" do
      expect(form_attributes.length).to eq(1)
      expect(form_attributes).to include(:uploads)
      uploads_attributes = form_attributes[:uploads]
      expect(uploads_attributes).not_to be_empty
      upload_attributes = uploads_attributes.first

      expect(upload_attributes).to include(id: work.pre_curation_uploads.first.id)
      expect(upload_attributes).to include(key: "https://doi.org/10.34770/123-abc/#{work.id}/us_covid_2019.csv")
      expect(upload_attributes).to include(filename: "us_covid_2019.csv")
      expect(upload_attributes).to include(:created_at)
      expect(upload_attributes[:created_at]).to be_a(ActiveSupport::TimeWithZone)
      expect(upload_attributes).to include(:url)
      expect(upload_attributes[:url]).to include("/rails/active_storage/blobs/redirect/")
      expect(upload_attributes[:url]).to include("/us_covid_2019.csv?disposition=attachment")
    end
  end
end
