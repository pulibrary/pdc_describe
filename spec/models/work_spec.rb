# frozen_string_literal: true
require "rails_helper"

RSpec.describe Work, type: :model do
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

  let(:uploaded_file) do
    fixture_file_upload("us_covid_2019.csv", "text/csv")
  end

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
    expect(a_request(:post, "https://#{Rails.configuration.datacite.host}/dois")).to have_been_made.once
  end

  it "prevents datasets with no users" do
    work = Work.new(collection: collection, resource: PDCMetadata::Resource.new)
    expect { work.draft! }.to raise_error AASM::InvalidTransition
  end

  it "prevents datasets with no collections" do
    work = Work.new(collection: nil, resource: FactoryBot.build(:resource))
    expect { work.save! }.to raise_error ActiveRecord::RecordInvalid
  end

  it "prevents invalid state assignment" do
    work = Work.new
    expect { work.state = "sorry" }.to raise_error(StandardError, /Invalid state 'sorry'/)
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

  context "with related objects" do
    subject(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work) }
    it "has related objects" do
      expect(work.resource.related_objects.first.related_identifier).to eq "https://www.biorxiv.org/content/10.1101/545517v1"
      expect(work.resource.related_objects.first.related_identifier_type).to eq "arXiv"
      expect(work.resource.related_objects.first.relation_type).to eq "IsCitedBy"
    end
  end

  context "with a persisted dataset work" do
    subject(:work) { FactoryBot.create(:draft_work) }

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
    file_name = uploaded_file.original_filename
    stub_work_s3_requests(work: work, file_name: file_name)
    work.pre_curation_uploads.attach(uploaded_file)
    stub_datacite_doi
    work.complete_submission!(user)
    work.approve!(curator_user)
    # The put for precuration upload
    expect(a_request(:put, "https://example-bucket.s3.amazonaws.com/#{work.s3_object_key}/#{file_name}")).to have_been_made
    expect(work.state_history.first.state).to eq "approved"
    expect(work.reload.state).to eq("approved")
  end

  context "when files are attached to a pre-curation Work" do
    subject(:work) { FactoryBot.create(:draft_work) }
    let(:uploaded_file) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end
    let(:uploaded_file2) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end
    let(:post_curation_data_profile) do
      {
        objects: [
          S3File.new(
            query_service: pre_curated_query_service,
            filename: "#{work.doi}/#{work.id}/us_covid_2019.csv",
            last_modified: nil,
            size: nil,
            checksum: ""
          ),
          S3File.new(
            query_service: pre_curated_query_service,
            filename: "#{work.doi}/#{work.id}/us_covid_2019_2.csv",
            last_modified: nil,
            size: nil,
            checksum: ""
          )
        ]
      }
    end
    let(:pre_curated_data_profile) do
      {
        objects: []
      }
    end
    let(:pre_curated_query_service) { instance_double(S3QueryService) }
    let(:s3_client) { instance_double(Aws::S3::Client) }

    before do
      allow(s3_client).to receive(:copy_object)
      allow(s3_client).to receive(:head_object).with(bucket: "example-bucket", key: "10.34770/123-abc/#{work.id}").and_raise(Aws::S3::Errors::NotFound.new(true, "test error"))
      allow(s3_client).to receive(:head_object).with(bucket: "example-bucket", key: "10.34770/123-abc/#{work.id}/us_covid_2019.csv").and_return(true)
      allow(s3_client).to receive(:head_object).with(bucket: "example-bucket", key: "10.34770/123-abc/#{work.id}/us_covid_2019_2.csv").and_return(true)
      allow(s3_client).to receive(:delete_object).and_return(nil)

      allow(pre_curated_query_service).to receive(:data_profile).and_return(
        pre_curated_data_profile,
        post_curation_data_profile
      )
      allow(pre_curated_query_service).to receive(:bucket_name).and_return("example-bucket")
      allow(pre_curated_query_service).to receive(:client).and_return(s3_client)
      allow(S3QueryService).to receive(:new).and_return(pre_curated_query_service)

      stub_request(:delete, /#{attachment_url}/).to_return(status: 200)
      stub_request(:get, /#{attachment_url}/).to_return(status: 200, body: "test_content")
      stub_request(:put, /#{attachment_url}/).with(
        body: "date,state,fips,cases,deaths\n2020-01-21,Washington,53,1,0\n2022-07-10,Wyoming,56,165619,1834\n"
      ).to_return(status: 200)
      stub_datacite_doi

      work.complete_submission!(user)
      work.reload
      2.times { work.pre_curation_uploads.attach(uploaded_file) }
      work.save!
      allow(pre_curated_query_service).to receive(:publish_files).and_return([work.pre_curation_uploads.first, work.pre_curation_uploads.last])
    end

    context "when a Work is approved" do
      it "transfers the files to the AWS Bucket" do
        first_attachment = work.pre_curation_uploads.first
        first_attachment_key = first_attachment.key
        last_attachment = work.pre_curation_uploads.last
        last_attachment_key = last_attachment.key

        work.approve!(curator_user)
        work.reload

        expect(pre_curated_query_service).to have_received(:publish_files).once
        expect(work.pre_curation_uploads).to be_empty
        expect(work.post_curation_uploads).not_to be_empty
        expect(work.post_curation_uploads.length).to eq(2)
        expect(work.post_curation_uploads.first).to be_an(S3File)
        expect(work.post_curation_uploads.first.key).to eq(first_attachment_key)
        expect(work.post_curation_uploads.last).to be_an(S3File)
        expect(work.post_curation_uploads.last.key).to eq(last_attachment_key)
      end
    end
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
      file_name = uploaded_file.original_filename
      stub_work_s3_requests(work: work, file_name: file_name)
      work.pre_curation_uploads.attach(uploaded_file)
      work.resource.ark = ezid
      work.save
      work.complete_submission!(user)
      stub_datacite_doi
      work.approve!(curator_user)
      expect(Ark).to have_received(:update).exactly(1).times
    end

    it "does not update the ARK metadata when it is nil" do
      file_name = uploaded_file.original_filename
      stub_work_s3_requests(work: work, file_name: file_name)
      work.pre_curation_uploads.attach(uploaded_file)
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
      expect(work.resource.doi).to eq "10.34770/pe9w-x904"
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

  describe "#add_message" do
    it "adds a message" do
      work.add_message("hello world", user.id)
      activity = work.activities.find { |a| a.message.include?("hello world") }
      expect(activity.created_by_user.id).to eq user.id
      expect(activity.activity_type).to eq WorkActivity::MESSAGE
    end

    it "logs notifications" do
      expect(work.new_notification_count_for_user(user.id)).to eq 0
      expect(work.new_notification_count_for_user(curator_user.id)).to eq 0

      work.add_message("taggging @#{curator_user.uid}", user.id)
      work2.add_message("taggging @#{curator_user.uid}", user.id)
      expect(work.new_notification_count_for_user(user.id)).to eq 0
      expect(work.new_notification_count_for_user(curator_user.id)).to eq 1

      work.mark_new_notifications_as_read(curator_user.id)
      expect(work.new_notification_count_for_user(curator_user.id)).to eq 0
    end

    it "parses tagged users correctly" do
      message = "taggging @#{curator_user.uid} and @#{user_other.uid}"
      work.add_message(message, user.id)
      activity = work.activities.find { |a| a.message.include?(message) }
      expect(activity.to_html.include?("#{curator_user.uid}</a>")).to be true
      expect(activity.to_html.include?("#{user_other.uid}</a>")).to be true
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
  end

  describe "#draft" do
    let(:draft_work) do
      work = Work.new(collection: collection, resource: FactoryBot.build(:resource), created_by_user_id: user.id)
      work.draft!(user)
      work = Work.find(work.id)
      work
    end

    it "transitions from none to draft" do
      expect(draft_work.reload.state).to eq("draft")
    end

    it "drafts a doi and the DOI is persisted" do
      draft_work
      expect(a_request(:post, "https://#{Rails.configuration.datacite.host}/dois")).to have_been_made
      expect(draft_work.resource.doi).not_to eq nil
    end

    it "Notifies Curators and Depositor" do
      # enable emails
      user.email_messages_enabled = true
      # Can not enable message for a depositor, but we will not send them without the messages being enabled
      # user.enable_messages_from(collection: collection)
      curator_user.email_messages_enabled = true
      curator_user.enable_messages_from(collection: collection)
      expect { draft_work }
        .to change { WorkActivity.where(activity_type: "SYSTEM").count }.by(2)
        .and have_enqueued_job(ActionMailer::MailDeliveryJob).once # this would be twice if the user could enable messages
      expect(WorkActivity.where(activity_type: "SYSTEM").first.message).to eq("marked as Draft")
      user_notification = WorkActivity.where(activity_type: "SYSTEM").last.message
      expect(user_notification).to include("@#{curator_user.uid}")
      expect(user_notification).to include("@#{user.uid}")
      expect(user_notification). to include(Rails.application.routes.url_helpers.work_url(draft_work))
    end

    context "when deploying the server without a DataCite user configured" do
      let!(:datacite_user) do
        Rails.configuration.datacite.user
      end

      before do
        Rails.configuration.datacite.user = nil
        draft_work
      end

      after do
        Rails.configuration.datacite.user = datacite_user
      end

      it "does not drafts a new DOI, but uses the test DOI" do
        expect(draft_work.reload.state).to eq("draft")
        expect(draft_work.doi).to eq("10.34770/tbd")
      end
    end

    context "when creating the DataCite DOI fails" do
      let(:data_cite_failure) { double }
      let(:data_cite_result) { double }
      let(:data_cite_connection) { double }

      before do
        allow(data_cite_failure).to receive(:reason_phrase).and_return("test status")
        allow(data_cite_failure).to receive(:status).and_return("test status")
        allow(data_cite_result).to receive(:failure).and_return(data_cite_failure)
        allow(data_cite_result).to receive(:success?).and_return(false)
        allow(data_cite_connection).to receive(:autogenerate_doi).and_return(data_cite_result)
        allow(Datacite::Client).to receive(:new).and_return(data_cite_connection)
      end

      it "raises an error" do
        expect { draft_work }.to raise_error(StandardError)
      end
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
      file_name = uploaded_file.original_filename
      stub_work_s3_requests(work: awaiting_approval_work, file_name: file_name)
      awaiting_approval_work.pre_curation_uploads.attach(uploaded_file)
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

    it "notifies the curator and depositor it is ready for review" do
      curator = FactoryBot.create(:research_data_moderator)
      # enable emails
      user.email_messages_enabled = true
      # Can not enable message for a depositor, but we will not send them without the messages being enabled
      # user.enable_messages_from(collection: collection)
      curator.email_messages_enabled = true
      curator.enable_messages_from(collection: collection)
      expect { awaiting_approval_work }
        .to change { WorkActivity.where(activity_type: "SYSTEM").count }.by(2)
        .and have_enqueued_job(ActionMailer::MailDeliveryJob).once # this would be twice if the user could enable messages
      expect(WorkActivity.where(activity_type: "SYSTEM").first.message).to eq("marked as Awaiting Approval")
      curator_notification = WorkActivity.where(activity_type: "SYSTEM").last.message
      expect(curator_notification).to include("@#{curator.uid}")
      expect(curator_notification). to include(Rails.application.routes.url_helpers.work_url(awaiting_approval_work))
    end
  end

  describe "#approve" do
    let(:approved_work) do
      work = FactoryBot.create :awaiting_approval_work
      file_name = uploaded_file.original_filename
      stub_work_s3_requests(work: work, file_name: file_name)
      work.pre_curation_uploads.attach(uploaded_file)
      work.approve!(curator_user)
      work
    end

    context "when the curator user has been set" do
      let(:data_cite_failure) { double }
      let(:data_cite_result) { double }
      let(:data_cite_connection) { double }
      let!(:datacite_user) { Rails.configuration.datacite.user }

      before do
        Rails.configuration.datacite.user = "test_user"

        allow(data_cite_failure).to receive(:reason_phrase).and_return("test status")
        allow(data_cite_failure).to receive(:status).and_return("test status")
        allow(data_cite_result).to receive(:failure).and_return(data_cite_failure)

        allow(data_cite_result).to receive(:failure?).and_return(true)
        allow(data_cite_connection).to receive(:update).and_return(data_cite_result)
        allow(Datacite::Client).to receive(:new).and_return(data_cite_connection)

        stub_request(:put, "https://api.datacite.org/dois/10.34770/123-abc")
      end

      after do
        Rails.configuration.datacite.user = datacite_user
      end

      it "is approved" do
        draft_work = FactoryBot.create(:draft_work)
        file_name = uploaded_file.original_filename
        stub_work_s3_requests(work: draft_work, file_name: file_name)
        draft_work.pre_curation_uploads.attach(uploaded_file)

        draft_work.complete_submission!(user)
        draft_work.update_curator(curator_user.id, user)
        draft_work.approve!(curator_user)
        draft_work.reload

        expect(draft_work.curator).to eq(curator_user)
      end
    end

    it "is approved" do
      stub_datacite_doi
      expect(approved_work.reload.state).to eq("approved")
    end

    it "Notifies Curators and Depositor" do
      stub_datacite_doi
      # enable emails
      user.email_messages_enabled = true
      # Can not enable message for a depositor, but we will not send them without the messages being enabled
      # user.enable_messages_from(collection: collection)
      curator_user.email_messages_enabled = true
      curator_user.enable_messages_from(collection: collection)
      expect { approved_work }
        .to change { WorkActivity.where(activity_type: "SYSTEM").count }.by(2)
        .and have_enqueued_job(ActionMailer::MailDeliveryJob).once # this would be twice if the user could enable messages
      expect(WorkActivity.where(activity_type: "SYSTEM").first.message).to eq("marked as Approved")
      user_notification = WorkActivity.where(activity_type: "SYSTEM").last.message
      expect(user_notification).to include("@#{curator_user.uid}")
      expect(user_notification).to include("@#{approved_work.created_by_user.uid}")
      expect(user_notification). to include(Rails.application.routes.url_helpers.work_url(approved_work))
    end

    it "publishes the doi" do
      stub_request(:put, "https://api.datacite.org/dois/10.34770/123-abc")
      expect { approved_work }.to change { WorkActivity.where(activity_type: "DATACITE_ERROR").count }.by(0)
      expect(a_request(:put, "https://api.datacite.org/dois/10.34770/123-abc")).to have_been_made
    end

    context "after the DOI has been published" do
      let(:payload_xml) do
        r = PDCMetadata::Resource.new_from_jsonb(approved_work.metadata)
        unencoded = r.to_xml
        Base64.encode64(unencoded)
      end

      before do
        stub_request(:put, "https://api.datacite.org/dois/10.34770/123-abc")
        approved_work
      end

      it "transmits a PUT request with the DOI attributes" do
        expect(
          a_request(:put, "https://api.datacite.org/dois/10.34770/123-abc").with(
            headers: {
              "Content-Type" => "application/vnd.api+json"
            },
            body: {
              "data": {
                "attributes": {
                  "event": "publish",
                  "xml": payload_xml,
                  "url": "https://datacommons.princeton.edu/discovery/doi/#{work.doi}"
                }
              }
            }
          )
        ).to have_been_made
      end
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

  describe "#save", mock_s3_query_service: false do
    context "when the Work is persisted and not yet in the approved state" do
      let(:work) { FactoryBot.create(:draft_work) }

      let(:s3_query_service_double) { instance_double(S3QueryService) }
      let(:file1) do
        S3File.new(
        filename: "#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_README.txt",
        last_modified: Time.parse("2022-04-21T18:29:40.000Z"),
        size: 10_759,
        checksum: "abc123"
      )
      end
      let(:file2) do
        S3File.new(
          filename: "#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json",
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
        # call the s3 reload and make sure no more files get added to the model
        work.attach_s3_resources

        expect(work.pre_curation_uploads).not_to be_empty
        expect(work.pre_curation_uploads.length).to eq(2)
        expect(work.pre_curation_uploads.first).to be_a(ActiveStorage::Attachment)
        expect(work.pre_curation_uploads.first.key).to eq("#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_README.txt")
        expect(work.pre_curation_uploads.last).to be_a(ActiveStorage::Attachment)
        expect(work.pre_curation_uploads.last.key).to eq("#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json")
        expect(work.activities.count { |a| a.activity_type == "FILE-CHANGES" }).to eq(1)

        # call the s3 reload and make sure no more files get added to the model
        work.attach_s3_resources
        expect(work.pre_curation_uploads.length).to eq(2)
        expect(work.activities.count { |a| a.activity_type == "FILE-CHANGES" }).to eq(1)
      end

      context "a blob already exists for one of the files" do
        # Here is the first Blob which is already attached
        let(:persisted_blob1) do
          persisted = ActiveStorage::Blob.create_before_direct_upload!(
            filename: file1.filename, content_type: "", byte_size: file1.size, checksum: ""
          )
          persisted.key = file1.filename
          persisted
        end
        # Here is the second Blob which is exists in the S3 Bucket but is not yet attached
        let(:persisted_blob2) do
          persisted = ActiveStorage::Blob.create_before_direct_upload!(
            filename: file2.filename, content_type: "", byte_size: file2.size, checksum: ""
          )
          persisted.key = file2.filename
          persisted
        end

        before do
          allow(ActiveStorage::Blob).to receive(:find_by).and_return(persisted_blob2)
          work.pre_curation_uploads.attach(persisted_blob1)

          work.attach_s3_resources
        end

        it "finds the blob and attaches it as an ActiveStorage Attachments" do
          expect(work.pre_curation_uploads).not_to be_empty
          expect(work.pre_curation_uploads.length).to eq(2)
          expect(work.pre_curation_uploads.first).to be_a(ActiveStorage::Attachment)
          expect(work.pre_curation_uploads.first.key).to eq("#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_README.txt")
          expect(work.pre_curation_uploads.first.blob).to eq(persisted_blob1)
          expect(work.pre_curation_uploads.last).to be_a(ActiveStorage::Attachment)
          expect(work.pre_curation_uploads.last.key).to eq("#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json")
          expect(work.pre_curation_uploads.last.blob).to eq(persisted_blob2)
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
      expect(upload_attributes).to include(key: "10.34770/123-abc/#{work.id}/us_covid_2019.csv")
      expect(upload_attributes).to include(filename: "us_covid_2019.csv")
      expect(upload_attributes).to include(:created_at)
      expect(upload_attributes[:created_at]).to be_a(ActiveSupport::TimeWithZone)
      expect(upload_attributes).to include(:url)
      expect(upload_attributes[:url]).to include("/rails/active_storage/blobs/redirect/")
      expect(upload_attributes[:url]).to include("/us_covid_2019.csv?disposition=attachment")
    end
  end

  describe ".curator_or_current_uid" do
    it "finds the existing User using the ID" do
      persisted = work.curator_or_current_uid(user)
      expect(persisted).to eq(user.uid)
    end
  end

  describe "resource=" do
    let(:resource_json) do
      '{
        "titles": [
          {
            "title": "Planet of the Blue Rain",
            "title_type": null
          },
          {
            "title": "the subtitle",
            "title_type": "Subtitle"
          }
        ],
        "description": "a new description",
        "collection_tags": [
          "new-colletion-tag1",
          "new-collection-tag2"
        ],
        "creators": [
          {
            "value": "Morrison, Toni",
            "name_type": "Personal",
            "given_name": "Toni",
            "family_name": "Morrison",
            "identifier": null,
            "affiliations": [],
            "sequence": 1
          }
        ],
        "resource_type": "digitized video",
        "resource_type_general": "Audiovisual",
        "publisher": "Princeton University",
        "publication_year": 2022,
        "ark": "new-ark",
        "doi": "new-doi",
        "rights": {
          "identifier": "CC BY",
          "uri": "https://creativecommons.org/licenses/by/4.0/",
          "name": "Creative Commons Attribution 4.0 International"
        },
        "version_number": "1",
        "related_objects": [],
        "keywords": [],
        "contributors": [],
        "funders":[
          {
            "funder_name": "National Science Foundation",
            "award_number": "nsf-123",
            "award_uri": "http://nsg.gov/award/123"
          }
        ]
      }'
    end
    it "can change the entire resource" do
      parsed_json = JSON.parse(resource_json)
      work.resource = PDCMetadata::Resource.new_from_jsonb(parsed_json)
      expect(work.resource.to_json).to eq(parsed_json.to_json)
    end
  end

  describe "valid_to_submit" do
    it "validates the work is ready to submit" do
      expect(work.valid_to_submit).to be_truthy
    end

    context "with a related identifier without a type" do
      before do
        work.resource.related_objects << PDCMetadata::RelatedObject.new(related_identifier: "http://related.example.com", related_identifier_type: nil, relation_type: nil)
      end

      it "validates the work is not ready to submit" do
        expect(work.valid_to_submit).to be_falsey
        expect(work.errors.count).to eq(1)
        expect(work.errors.first.type). to eq("Related Objects are invalid: Related Identifier Type is missing or invalid for http://related.example.com, Relationship Type is missing or invalid for http://related.example.com")
      end
    end
  end

  describe "valid?" do
    it "requires a collection" do
      work = Work.new(created_by_user_id: user.id, collection_id: nil, user_entered_doi: false)
      expect(work).not_to be_valid
    end

    it "requires a collection on update of a draft work" do
      work.update({ collection_id: "", resource: work.resource })
      expect(work.collection).to be_nil
      expect(work).not_to be_valid
    end
  end

  describe "delete" do
    it "cleans up all the related objects" do
      work.complete_submission!(user)
      expect { work.destroy }.to change { Work.count }.by(-1)
                                                      .and change { UserWork.count }.by(-1)
                                                                                    .and change { WorkActivity.count }.by(-2)
    end
  end
end
