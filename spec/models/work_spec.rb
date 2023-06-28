# frozen_string_literal: true
require "rails_helper"

RSpec.describe Work, type: :model do
  let(:user) { FactoryBot.create :user }
  let(:group) { Group.research_data }
  let(:user_other) { FactoryBot.create :user }
  let(:super_admin_user) { FactoryBot.create :super_admin_user }
  let(:work) { FactoryBot.create(:draft_work, doi: "10.34770/123-abc") }
  let(:work2) { FactoryBot.create(:draft_work) }

  let(:rd_user) { FactoryBot.create :princeton_submitter }

  let(:pppl_user) { FactoryBot.create :pppl_submitter }

  let(:curator_user) do
    FactoryBot.create :user, groups_to_admin: [Group.research_data]
  end

  # Please see spec/support/ezid_specs.rb
  let(:ezid) { @ezid }
  let(:identifier) { @identifier }
  let(:attachment_url) { /#{Regexp.escape("https://example-bucket.s3.amazonaws.com/")}/ }

  let(:uploaded_file) do
    fixture_file_upload("us_covid_2019.csv", "text/csv")
  end

  let(:doi) { work.doi }
  let(:s3_file) { FactoryBot.build :s3_file, filename: "#{doi}/test_key" }
  let(:client_s3_files) do
    [
      s3_file
    ]
  end
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:s3_query_service) { instance_double(S3QueryService) }
  let(:datacite_doi_result) { nil }
  let(:datacite_client) { stub_datacite_doi(result: datacite_doi_result) }
  let(:bucket_name) { "example-bucket" }

  before(:all) do
    RSpec.configuration.mock_attach_file_job = true
  end

  after(:all) do
    RSpec.configuration.mock_attach_file_job = false
  end

  before do
    # For tests in which the HTTP requests are submitted to WebMock
    stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
    # For cases in which the Datacite::Client objects are mocked
    datacite_client

    # s3_service
    allow(s3_query_service).to receive(:bucket_name).and_return(bucket_name)
    allow(s3_query_service).to receive(:client_s3_files).and_return(client_s3_files)
    allow(S3QueryService).to receive(:new).and_return(s3_query_service)
  end

  context "fixed time" do
    let(:group_json) do
      JSON.parse(group.to_json)
    end
    let(:group_created_at) do
      group_json["created_at"]
    end
    let(:group_updated_at) do
      group_json["updated_at"]
    end
    before do
      allow(Time).to receive(:now).and_return(Time.parse("2022-01-01T00:00:00.000Z"))
    end
    it "captures everything needed for PDC Describe in JSON" do
      work = Work.new(group: group, resource: FactoryBot.build(:tokamak_work))
      expect(JSON.parse(work.to_json)).to eq(
        {
          "resource" => {
            "titles" => [],
            "description" => nil,
            "collection_tags" => [],
            "creators" => [],
            "organizational_contributors" => [],
            "resource_type" => nil,
            "resource_type_general" => nil,
            "publisher" => nil,
            "publication_year" => nil,
            "ark" => nil,
            "doi" => nil,
            "rights" => nil,
            "version_number" => nil,
            "related_objects" => [],
            "keywords" => [],
            "contributors" => [],
            "funders" => [],
            "domains" => [],
            "communities" => [],
            "subcommunities" => [],
            "migrated" => false
          },
          "files" => [],
          "group" => {
            "title" => "Princeton Research Data Service (PRDS)",
            "description" => nil,
            "code" => "RD",
            "created_at" => group_created_at,
            "updated_at" => group_updated_at
          }
        }
      )
    end
  end

  it "checks the format of the ORCID of the creators" do
    # Add a new creator with an incomplete ORCID
    work.resource.creators << PDCMetadata::Creator.new_person("Williams", "Serena", "1234-12")
    expect(work.save).to be false
    expect(work.errors.find { |error| error.type.include?("ORCID") }).to be_present
  end

  it "drafts a doi only once" do
    work = Work.new(group: group, resource: FactoryBot.build(:resource, doi: ""))
    work.draft_doi
    work.draft_doi # Doing this multiple times on purpose to make sure the api is only called once
    expect(datacite_client).to have_received(:autogenerate_doi).once
  end

  it "prevents datasets with no users" do
    work = Work.new(group: group, resource: PDCMetadata::Resource.new)
    expect { work.draft! }.to raise_error AASM::InvalidTransition
  end

  it "prevents datasets with no collections" do
    work = Work.new(group: nil, resource: FactoryBot.build(:resource))
    expect { work.save! }.to raise_error ActiveRecord::RecordInvalid
  end

  it "prevents invalid state assignment" do
    work = Work.new
    expect { work.state = "sorry" }.to raise_error(StandardError, /Invalid state 'sorry'/)
  end

  # Check the application config to determine whether this work should skip DataSpace file downloading
  # This is a workaround because some objects have data so large the files cannot be automatically fetched
  # from DataSpace and they must be moved manually.
  describe "#skip_dataspace_migration?" do
    it "is false by default" do
      expect(work.skip_dataspace_migration?).to be_falsey
    end
    it "is true if the ARK is in the manual migration config" do
      work.resource.ark = "ark:/88435/dsp01h415pd457"
      expect(work.skip_dataspace_migration?).to be_truthy
    end
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

    it "is editable by group admins of its group" do
      expect(work.editable_by?(pppl_moderator)).to eq true
    end

    it "is editable by super admins" do
      expect(work.editable_by?(super_admin)).to eq true
    end

    it "is not editable by another user" do
      expect(work.editable_by?(other_user)).to eq false
    end

    it "is not editable by a group admin of a different group" do
      expect(work.editable_by?(research_data_moderator)).to eq false
    end
  end

  context "with related objects" do
    subject(:work) { FactoryBot.create(:distinct_cytoskeletal_proteins_work, ark: doi) }

    let(:doi) { "ark:/88435/xyz123" }

    before do
      @ezid = doi
      stub_ark
    end

    it "has related objects" do
      expect(work.resource.related_objects.first.related_identifier).to eq "https://www.biorxiv.org/content/10.1101/545517v1"
      expect(work.resource.related_objects.first.related_identifier_type).to eq "arXiv"
      expect(work.resource.related_objects.first.relation_type).to eq "IsCitedBy"
    end
  end

  context "when files are attached to a pre-curation Work" do
    before do
      stub_datacite_doi
    end

    it "approves works and records the change history" do
      file1 = FactoryBot.build(:s3_file, filename: "us_covid_2019.csv", size: 1024)
      file2 = FactoryBot.build(:s3_file, filename: "us_covid_2019_2.csv", size: 2048)

      s3_client = instance_double(Aws::S3::Client)
      s3_query_service1 = instance_double(S3QueryService)

      allow(s3_query_service1).to receive(:publish_files)
      allow(s3_query_service1).to receive(:data_profile).and_return({ objects: [file1, file2] })
      allow(s3_query_service1).to receive(:client).and_return(s3_client)
      allow(s3_query_service1).to receive(:bucket_name).and_return("example-post-bucket")
      allow(s3_query_service1).to receive(:client_s3_files).and_return(client_s3_files)
      allow(S3QueryService).to receive(:new).and_return(s3_query_service1)

      work1 = FactoryBot.create(:awaiting_approval_work, doi: "10.34770/123-abc")
      allow(s3_client).to receive(:head_object).with(bucket: "example-post-bucket", key: work1.s3_object_key).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))

      work1.approve!(curator_user)

      expect(s3_query_service1).to have_received(:publish_files).once
      expect(work1.state_history.first.state).to eq "approved"
      expect(work1.reload.state).to eq("approved")
    end

    context "when a Work is approved" do
      it "transfers the files to the AWS Bucket" do
        stub_datacite_doi
        file1 = FactoryBot.build(:s3_file, filename: "10.34770/123-abc/1/us_covid_2019.csv", size: 1024)
        file2 = FactoryBot.build(:s3_file, filename: "10.34770/123-abc/1/us_covid_2019_2.csv", size: 2048)

        s3_client = instance_double(Aws::S3::Client)
        s3_query_service1 = instance_double(S3QueryService)

        allow(s3_query_service1).to receive(:publish_files)
        allow(s3_query_service1).to receive(:data_profile).and_return({ objects: [file1, file2] })
        allow(s3_query_service1).to receive(:client).and_return(s3_client)
        allow(s3_query_service1).to receive(:bucket_name).and_return("example-post-bucket")
        allow(s3_query_service1).to receive(:client_s3_files).and_return(client_s3_files)
        allow(S3QueryService).to receive(:new).and_return(s3_query_service1)

        work1 = FactoryBot.create(:awaiting_approval_work, doi: "10.34770/123-abc")
        allow(s3_client).to receive(:head_object).with(bucket: "example-post-bucket", key: work1.s3_object_key).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))

        work1.approve!(curator_user)

        expect(s3_query_service1).to have_received(:publish_files).once
        expect(work1.state_history.first.state).to eq "approved"
        expect(work1.reload.state).to eq("approved")

        expect(work1.as_json["files"][0].keys).to eq([:filename, :size, :display_size, :url])
        expect(work1.as_json["files"][0][:filename]).to match(/10\.34770\/123-abc\/\d+\/us_covid_2019\.csv/)
        expect(work1.as_json["files"][0][:size]).to eq(1024)
        expect(work1.as_json["files"][0][:display_size]).to eq("1 KB")
        expect(work1.as_json["files"][0][:url]).to eq "https://example.data.globus.org/10.34770/123-abc/1/us_covid_2019.csv"
      end
    end

    context "when the doi is empty" do
      it "fails the transition" do
        work1 = FactoryBot.create(:awaiting_approval_work, doi: "10.34770/123-abc")

        expect(work1.reload.state).to eq("awaiting_approval")
        work1.resource.doi = ""
        expect { work1.approve!(curator_user) }.to raise_error(AASM::InvalidTransition)
        expect(work1.errors.map(&:type)).to eq(["DOI must be present for a work to be approved"])
        expect(work1.reload.state).to eq("awaiting_approval")
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
    let(:s3_file) { instance_double(S3File, filename: "test.txt") }
    let(:s3_service_data) { [s3_file] }
    let(:s3_client) { double }
    let(:work) { FactoryBot.create(:draft_work, doi: "10.34770/123-abc") }

    around do |example|
      Rails.configuration.update_ark_url = true
      example.run
      Rails.configuration.update_ark_url = false
    end

    before do
      allow(s3_query_service).to receive(:publish_files)
      allow(s3_query_service).to receive(:client).and_return(s3_client)
      allow(s3_client).to receive(:head_object).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))
    end

    it "updates the ARK metadata" do
      work.resource.ark = ezid
      work.save
      work.complete_submission!(user)
      stub_datacite_doi
      work.approve!(curator_user)
      expect(Ark).to have_received(:update).exactly(1).times
    end

    it "does not update the ARK metadata when it is nil" do
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
      let(:group_id) { group.id }

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
      activity = WorkActivity.changes_for_work(work.id).last
      expect(activity.message).to eq("Set curator to @#{curator_user.uid}")
      expect(work.curator.id).to be curator_user.id
      expect(activity.created_by_user.id).to eq user.id

      work.change_curator(user.id, user)
      activity = WorkActivity.changes_for_work(work.id).last
      expect(activity.message).to eq("Self-assigned as curator")
      expect(work.curator.id).to be user.id
      expect(activity.created_by_user.id).to eq user.id

      work.clear_curator(user)
      activity = WorkActivity.changes_for_work(work.id).last
      expect(activity.message).to eq("Unassigned existing curator")
      expect(work.curator).to be nil
      expect(activity.created_by_user.id).to eq user.id
    end
  end

  describe "#add_message" do
    it "adds a message" do
      work.add_message("hello world", user.id)
      activity = WorkActivity.messages_for_work(work.id).first
      expect(activity.message).to eq("hello world")
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
      activity = WorkActivity.messages_for_work(work.id).first
      expect(activity.message).to eq(message)
      expect(activity.to_html.include?("#{curator_user.uid}</a>")).to be true
      expect(activity.to_html.include?("#{user_other.uid}</a>")).to be true
    end
  end

  # Is this test providing any coverage?
  describe "#pre_curation_uploads" do
    let(:uploaded_file) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end

    let(:uploaded_file2) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end

    let(:s3_service_data) { [] }
    let(:s3_service) { stub_s3(data: s3_service_data) }

    before do
      s3_service

      stub_request(:put, /#{attachment_url}/).with(
        body: "date,state,fips,cases,deaths\n2020-01-21,Washington,53,1,0\n2022-07-10,Wyoming,56,165619,1834\n"
      ).to_return(status: 200)

      work.pre_curation_uploads.attach(uploaded_file)
      work.save
    end
  end

  describe "#draft" do
    let(:draft_work) do
      work = Work.new(group: group, resource: FactoryBot.build(:resource), created_by_user_id: user.id)
      work.draft!(user)
      work = Work.find(work.id)
      work
    end

    it "transitions from none to draft" do
      expect(draft_work.reload.state).to eq("draft")
    end

    it "drafts a doi and the DOI is persisted" do
      draft_work
      expect(datacite_client).to have_received(:autogenerate_doi)
      expect(draft_work.resource.doi).not_to eq nil
    end

    it "Notifies Curators and Depositor" do
      curator_user
      expect { draft_work }
        .to change { WorkActivity.where(activity_type: WorkActivity::SYSTEM).count }.by(1)
        .and change { WorkActivity.where(activity_type: WorkActivity::NOTIFICATION).count }.by(1)
        .and have_enqueued_job(ActionMailer::MailDeliveryJob).twice
      expect(WorkActivity.where(activity_type: "SYSTEM").first.message).to eq("marked as Draft")
      user_notification = WorkActivity.where(activity_type: WorkActivity::NOTIFICATION).last.message
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
      let(:datacite_client_doi_body) { @datacite_client_doi_body }
      let(:datacite_client_doi_response) { @datacite_client_doi_response }
      let(:datacite_client_doi_status) { Failure("It failed") }

      before(:all) do
        @datacite_client_doi_success = false
      end

      after(:all) do
        @datacite_client_doi_success = true
      end

      before do
        allow(datacite_client_doi_body).to receive(:reason_phrase).and_return("test status")
        allow(datacite_client_doi_body).to receive(:status).and_return("test status")
        allow(datacite_client_doi_response).to receive(:failure).and_return(datacite_client_doi_status)
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
    let(:bucket_name) { "example-bucket" }
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
      allow(s3_query_service).to receive(:publish_files)
      allow(s3_query_service).to receive(:client).and_return(s3_client)
      allow(s3_query_service).to receive(:bucket_name).and_return(bucket_name)
      allow(s3_client).to receive(:head_object).with(bucket: "example-bucket", key: awaiting_approval_work.s3_object_key).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))

      awaiting_approval_work.approve!(curator_user)
      expect(awaiting_approval_work.reload.state).to eq("approved")
    end

    context "submitter user" do
      let(:user) { FactoryBot.create(:princeton_submitter) }

      it "can not transition from awaitng_approval to approved" do
        stub_s3 data: [FactoryBot.build(:s3_file)]
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
      expect { awaiting_approval_work }
        .to change { WorkActivity.where(activity_type: WorkActivity::SYSTEM).count }.by(1)
        .and change { WorkActivity.where(activity_type: WorkActivity::NOTIFICATION).count }.by(1)
        .and have_enqueued_job(ActionMailer::MailDeliveryJob).twice
      expect(WorkActivity.where(activity_type: WorkActivity::SYSTEM).first.message).to eq("marked as Awaiting Approval")
      curator_notification = WorkActivity.where(activity_type: WorkActivity::NOTIFICATION).last.message
      expect(curator_notification).to include("@#{curator.uid}")
      expect(curator_notification). to include(Rails.application.routes.url_helpers.work_url(awaiting_approval_work))
    end
  end

  describe "#approve" do
    let(:fake_s3_service_pre) { stub_s3(data: [s3_file]) }
    let(:fake_s3_service_post) { stub_s3(data: [s3_file]) }
    # Approved Works require uploaded files
    let(:s3_file) { instance_double(S3File) }
    let(:s3_service_data) { [s3_file] }
    let(:doi) { "10.34770/123-abc" }
    let(:approved_work) { FactoryBot.create :awaiting_approval_work, doi: doi }

    before do
      allow(s3_file).to receive(:filename).and_return("test.txt")
    end

    context "when the curator user has been set" do
      let(:data_cite_failure) { double }
      let(:data_cite_result) { double }
      let(:data_cite_connection) { double }
      let!(:datacite_user) { Rails.configuration.datacite.user }

      # Approved Works require uploaded files
      let(:s3_file) { instance_double(S3File) }
      let(:client_s3_files) { [s3_file] }

      before do
        Rails.configuration.datacite.user = "test_user"

        allow(data_cite_failure).to receive(:reason_phrase).and_return("test status")
        allow(data_cite_failure).to receive(:status).and_return("test status")
        allow(data_cite_result).to receive(:failure).and_return(data_cite_failure)

        allow(data_cite_result).to receive(:failure?).and_return(true)
        allow(data_cite_connection).to receive(:update).and_return(data_cite_result)

        stub_request(:put, "https://api.datacite.org/dois/#{doi}")
      end

      after do
        Rails.configuration.datacite.user = datacite_user
      end

      context "with an assigned DOI" do
        let(:s3_client) { instance_double(Aws::S3::Client) }
        let(:s3_query_service) do
          # Stub the S3 api responses for constructing the object here
          stub_request(:get, "https://example-bucket.s3.amazonaws.com/?list-type=2&max-keys=1000&prefix=10.34770/123-abc//").to_return(status: 200, body: "", headers: {})
          S3QueryService.new(work, false)
        end
        let(:datacite_client) { instance_double(Datacite::Client) }
        let(:datacite_response) { double }
        let(:datacite_failure) { double }

        before do
          @stub_datacite = datacite_client
          allow(s3_file).to receive(:key).and_return("test-key")
          allow(s3_file).to receive(:size).and_return(0)
          stub_datacite_doi
        end

        context "with a work which has already been approved" do
          let(:user) { approved_work.created_by_user }

          before do
            allow(datacite_failure).to receive(:reason_phrase).and_return("test")
            allow(datacite_failure).to receive(:status).and_return(500)
            allow(datacite_response).to receive(:failure).and_return(datacite_failure)

            allow(datacite_response).to receive(:failure?).and_return(false)

            allow(datacite_client).to receive(:update).and_return(datacite_response)
            allow(s3_client).to receive(:head_object).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))
            allow(s3_query_service).to receive(:publish_files).and_call_original
            allow(s3_query_service).to receive(:client).and_return(s3_client)
            allow(s3_query_service).to receive(:bucket_name).and_return("example-pre-bucket", "example-post-bucket")

            allow(WorkActivity).to receive(:add_work_activity).and_call_original
            approved_work.update_curator(curator_user.id, user)
            approved_work.approve!(curator_user)
          end

          it "ensures that the curator is still set" do
            approved_work.reload

            expect(approved_work.curator).to eq(curator_user)
          end

          it "is approved" do
            expect(approved_work.reload.state).to eq("approved")
          end

          it "Notifies Curators and Depositor" do
            # def self.add_work_activity(work_id, message, user_id, activity_type:, created_at: nil)
            expect(WorkActivity).to have_received(:add_work_activity).with(
              approved_work.id, "Set curator to @#{curator_user.uid}", user.id, { activity_type: "SYSTEM" }
            )
            expect(WorkActivity).to have_received(:add_work_activity).with(
              approved_work.id, "marked as Approved", curator_user.id, { activity_type: "SYSTEM" }
            )
            expect(WorkActivity).to have_received(:add_work_activity).with(
              approved_work.id,
              "@#{curator_user.uid}, @#{user.uid} [#{approved_work.title}](#{Rails.application.routes.url_helpers.work_url(approved_work)}) has been approved.",
              curator_user.id,
              { activity_type: "NOTIFICATION" }
            )

            # expect { approved_work }
            #  .to change { WorkActivity.where(activity_type: WorkActivity::SYSTEM).count }.by(1)
            #  .and change { WorkActivity.where(activity_type: WorkActivity::NOTIFICATION).count }.by(1)
            #  .and have_enqueued_job(ActionMailer::MailDeliveryJob).twice
            # expect(WorkActivity.where(activity_type: WorkActivity::SYSTEM).first.message).to eq("marked as Approved")

            user_notification = WorkActivity.where(activity_type: WorkActivity::NOTIFICATION).last.message
            expect(user_notification).to include("@#{curator_user.uid}")
            expect(user_notification).to include("@#{approved_work.created_by_user.uid}")
            expect(user_notification). to include(Rails.application.routes.url_helpers.work_url(approved_work))
          end

          it "publishes the doi" do
            approved_work2 = FactoryBot.create(:awaiting_approval_work, doi: doi)

            expect { approved_work2 }.to change { WorkActivity.where(activity_type: WorkActivity::DATACITE_ERROR).count }.by(0)
            expect(datacite_client).to have_received(:update)
          end
        end
      end
    end

    context "after the DOI has been published" do
      let(:approved_work_metadata) do
        PDCMetadata::Resource.new_from_jsonb(approved_work.metadata)
      end
      let(:approved_work_metadata_xml) do
        approved_work_metadata.to_xml
      end
      let(:payload_xml) do
        Base64.encode64(approved_work_metadata_xml)
      end
      let(:ark) { "ark:/#{doi}" }
      let(:approved_work) { FactoryBot.create :awaiting_approval_work, ark: ark }
      let(:s3_object_key) { approved_work.s3_object_key }
      let(:ezid) { double(Ezid::Identifier) }
      let(:ezid_response_body) do
        <<-EOS
success: #{ark}
_updated: 1416507086
_target: http://ezid.cdlib.org/id/#{ark}
_profile: erc
_ownergroup: apitest
_owner: apitest
_export: yes
_created: 1416507086
_status: public
        EOS
      end

      before do
        allow(Ark).to receive(:update).and_call_original

        stub_request(:get, "https://ezid.cdlib.org/id/#{ark}").to_return(status: 200, body: ezid_response_body)
        stub_request(:post, "https://ezid.cdlib.org/id/#{ark}").to_return(status: 200, body: ezid_response_body)
        stub_request(:put, /#{Regexp.escape("https://api.datacite.org/dois/")}/).to_return(status: 200)

        allow(s3_query_service).to receive(:publish_files)
        allow(s3_query_service).to receive(:client).and_return(s3_client)
        allow(s3_query_service).to receive(:bucket_name).and_return("example-pre-bucket", "example-post-bucket")
        allow(s3_client).to receive(:head_object).with(bucket: "example-post-bucket", key: s3_object_key).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))
        allow(s3_client).to receive(:head_object).with(bucket: "example-pre-bucket", key: s3_object_key).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))

        allow(Rails.configuration).to receive(:update_ark_url).and_return(true)
        allow(Datacite::Client).to receive(:new).and_call_original

        approved_work.update_curator(curator_user.id, user)
        approved_work.approve!(curator_user)
      end

      it "transmits a PUT request with the DOI attributes" do
        expect(
          a_request(:put, "https://api.datacite.org/dois/#{approved_work.doi}").with(
            headers: {
              "Content-Type" => "application/vnd.api+json"
            },
            body: {
              "data": {
                "attributes": {
                  "event": "publish",
                  "xml": payload_xml,
                  "url": "https://datacommons.princeton.edu/discovery/doi/#{approved_work.doi}"
                }
              }
            }
          )
        ).to have_been_made
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

    context "when the DOI returns an error" do
      subject(:approved_work) { FactoryBot.create :awaiting_approval_work, ark: ark }
      let(:ark) { "ark:/#{doi}" }
      let(:datacite_doi_response_env) do
        Faraday::Env.new({
                           status: "bad",
                           reason_phrase: "a problem"
                         })
      end
      let(:datacite_doi_response) do
        Faraday::Response.new(datacite_doi_response_env)
      end
      let(:datacite_doi_result) do
        Failure(datacite_doi_response)
      end
      let(:ezid_response_body) do
        <<-EOS
success: #{ark}
_updated: 1416507086
_target: http://ezid.cdlib.org/id/#{ark}
_profile: erc
_ownergroup: apitest
_owner: apitest
_export: yes
_created: 1416507086
_status: public
        EOS
      end
      let(:s3_object_key) { approved_work.s3_object_key }

      before do
        stub_request(:get, "https://ezid.cdlib.org/id/#{ark}").to_return(status: 200, body: ezid_response_body)
        stub_request(:post, "https://ezid.cdlib.org/id/#{ark}").to_return(status: 200, body: ezid_response_body)

        allow(s3_query_service).to receive(:publish_files)
        allow(s3_query_service).to receive(:client).and_return(s3_client)
        allow(s3_query_service).to receive(:bucket_name).and_return("example-pre-bucket", "example-post-bucket")
        allow(s3_client).to receive(:head_object).with(bucket: "example-post-bucket", key: s3_object_key).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))
        allow(s3_client).to receive(:head_object).with(bucket: "example-pre-bucket", key: s3_object_key).and_raise(Aws::S3::Errors::NotFound.new("blah", "error"))
      end

      it "notes a issue when an error occurs" do
        approved_work.update_curator(curator_user.id, user)
        expect { approved_work.approve!(curator_user) }.to change { WorkActivity.where(activity_type: WorkActivity::DATACITE_ERROR).count }.by(1)
      end
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
    let(:work) { Work.new(group: group, resource: FactoryBot.build(:resource)) }
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

  describe "#save" do
    context "when the Work is persisted and not yet in the approved state" do
      let(:work) { FactoryBot.create(:draft_work) }

      let(:s3_query_service_double) { instance_double(S3QueryService) }
      let(:file1) do
        FactoryBot.build(:s3_file,
                          filename: "#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_README.txt",
                          last_modified: Time.parse("2022-04-21T18:29:40.000Z"),
                          size: 10_759,
                          checksum: "abc123",
                          work: work)
      end
      let(:file2) do
        FactoryBot.build(:s3_file,
          filename: "#{work.doi}/#{work.id}/SCoData_combined_v1_2020-07_datapackage.json",
          last_modified: Time.parse("2022-04-21T18:30:07.000Z"),
          size: 12_739,
          checksum: "abc567")
      end
      let(:s3_data) { [file1, file2] }
      let(:bucket_url) do
        "https://example-bucket.s3.amazonaws.com/"
      end

      before do
        # Account for files in S3 added outside of ActiveStorage
        # allow(S3QueryService).to receive(:new).and_return(s3_query_service_double)
        allow(s3_query_service_double).to receive(:data_profile).and_return({ objects: s3_data, ok: true })
        # Account for files uploaded to S3 via ActiveStorage
        stub_request(:put, /#{bucket_url}/).to_return(status: 200)

        work.complete_submission!(user)
        work.reload

        allow(Time).to receive(:now).and_return(Time.parse("2022-01-01T00:00:00.000Z"))
      end
    end
  end

  describe "#form_attributes" do
    let(:uploaded_file) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end
    let(:form_attributes) { work.form_attributes }
    let(:file1) do
      FactoryBot.build(:s3_file,
        filename: "#{work.doi}/#{work.id}/us_covid_2019.csv",
        last_modified: Time.parse("2022-04-21T18:29:40.000Z"),
        size: 10_759,
        checksum: "abc123",
        work: work)
    end
    let(:s3_service) { stub_s3(data: [], prefix: "10.34770/123/") }

    before do
      s3_service
      stub_request(:put, /#{attachment_url}/).with(
        body: "date,state,fips,cases,deaths\n2020-01-21,Washington,53,1,0\n2022-07-10,Wyoming,56,165619,1834\n"
      ).to_return(status: 200)

      work.pre_curation_uploads.attach(uploaded_file)
      work.save
    end

    it "generates JSON properties for each attribute" do
      allow(s3_service).to receive(:client_s3_files).and_return([file1])
      allow(s3_service).to receive(:file_url).with("10.34770/123-abc/#{work.id}/us_covid_2019.csv").and_return("https://example-bucket.s3.amazonaws.com/10.34770/123-abc/#{work.id}/us_covid_2019.csv")

      expect(form_attributes.length).to eq(1)
      expect(form_attributes).to include(:uploads)
      uploads_attributes = form_attributes[:uploads]
      expect(uploads_attributes).not_to be_empty
      upload_attributes = uploads_attributes.first

      expect(upload_attributes).to include(id: "10.34770/123-abc/#{work.id}/us_covid_2019.csv")
      expect(upload_attributes).to include(key: "10.34770/123-abc/#{work.id}/us_covid_2019.csv")
      expect(upload_attributes).to include(filename: "10.34770/123-abc/#{work.id}/us_covid_2019.csv")
      expect(upload_attributes).to include(:created_at)
      expect(upload_attributes[:created_at]).to be_a(Time)
      expect(upload_attributes).to include(:url)
      expect(upload_attributes[:url]).to eq("/works/#{work.id}/download?filename=10.34770%2F123-abc%2F#{work.id}%2Fus_covid_2019.csv")
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
        "organizational_contributors": [],
        "funders":[
          {
            "ror": "https://ror.org/012345678",
            "funder_name": "National Science Foundation",
            "award_number": "nsf-123",
            "award_uri": "http://nsg.gov/award/123"
          }
        ],
        "domains":[],
        "communities":[],
        "subcommunities":[],
        "migrated": false
      }'
    end
    it "can change the entire resource" do
      parsed_json = JSON.parse(resource_json)
      work.resource = PDCMetadata::Resource.new_from_jsonb(parsed_json)
      # Wrap with JSON.parse on both sides just so the diff is readable.
      expect(JSON.parse(work.resource.to_json)).to eq(JSON.parse(parsed_json.to_json))
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
    it "requires a group" do
      work = Work.new(created_by_user_id: user.id, group_id: nil, user_entered_doi: false)
      expect(work).not_to be_valid
    end

    it "requires a group on update of a draft work" do
      work.update({ group_id: "", resource: work.resource })
      expect(work.group).to be_nil
      expect(work).not_to be_valid
    end

    it "does not allow two of the same dois to be created" do
      stub_request(:get, "https://handle.stage.datacite.org/10.34770/123-zzz").to_return(status: 200, body: "", headers: {})
      original_work = FactoryBot.create(:none_work, doi: "10.34770/123-zzz", user_entered_doi: true)
      work = FactoryBot.build(:none_work, doi: "10.34770/123-zzz", user_entered_doi: true)
      expect(original_work).to be_valid
      expect(work).not_to be_valid
      expect(work.errors.first.type). to match(/Invalid DOI: It has already been applied to another work /)
    end

    it "does not allow two of the same arks to be created" do
      stub_ark
      original_work = FactoryBot.create(:draft_work, ark: "ark:/88435/xyz1234")
      work = FactoryBot.build(:draft_work, ark: "ark:/88435/xyz1234")
      expect(original_work).to be_valid
      expect(work).not_to be_valid
      expect(work.errors.first.type). to match(/Invalid ARK: It has already been applied to another work /)
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

  describe "pre_curation_uploads_count" do
    let(:s3_query_service) { instance_double(S3QueryService, file_count: 3, client_s3_files: []) }

    it "gets the count of the files on Amazon" do
      # allow(S3QueryService).to receive(:new).and_return(s3_query_service_double)

      expect(work.pre_curation_uploads_count).to eq(3)

      # only loads the data once
      expect(work.pre_curation_uploads_count).to eq(3)
      expect(S3QueryService).to have_received(:new).once
    end
  end

  describe "#upload_snapshots" do
    let(:upload_snapshot1) { FactoryBot.create(:upload_snapshot, work: work) }
    let(:upload_snapshot2) { FactoryBot.create(:upload_snapshot, work: work) }

    before do
      upload_snapshot1
      upload_snapshot2
    end

    it "accesses the associating UploadSnapshots" do
      expect(work.upload_snapshots).not_to be_empty
      expect(work.upload_snapshots.length).to eq(2)
      expect(work.upload_snapshots).to include(upload_snapshot1)
      expect(work.upload_snapshots).to include(upload_snapshot2)
    end
  end

  describe "#destroy" do
    let(:upload_snapshot1) { FactoryBot.create(:upload_snapshot, work: work) }
    let(:upload_snapshot2) { FactoryBot.create(:upload_snapshot, work: work) }

    before do
      upload_snapshot1
      upload_snapshot2
    end

    it "destroys all associated UploadSnapshots" do
      expect(work.upload_snapshots).not_to be_empty
      expect(work.upload_snapshots.length).to eq(2)
      expect(work.upload_snapshots).to include(upload_snapshot1)
      expect(work.upload_snapshots).to include(upload_snapshot2)

      work.destroy
      expect(UploadSnapshot.all).to be_empty
    end
  end

  describe "#find_by_doi" do
    let(:work) { FactoryBot.create(:draft_work, doi: "10.34770/123-zzz") }

    it "finds the work" do
      FactoryBot.create(:draft_work, doi: "10.34770/123-zzzz")
      work # make sure the work is present
      expect(Work.find_by_doi("10.34770/123-zzz")).to eq(work)
      expect(Work.find_by_doi("123-zzz")).to eq(work)
    end

    it "does not find partial matches" do
      work # make sure the work is present
      expect { Work.find_by_doi("10.34770/123-zz") }.to raise_error(ActiveRecord::RecordNotFound)
      expect { Work.find_by_doi("10.34770/123-zzzz") }.to raise_error(ActiveRecord::RecordNotFound)
      expect { Work.find_by_doi("123-zzzz") }.to raise_error(ActiveRecord::RecordNotFound)
      expect { Work.find_by_doi("123-zz") }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "can find nil dois" do
      work = FactoryBot.create(:draft_work, doi: nil)
      expect(Work.find_by_doi(nil)).to eq(work)
    end

    it "can find empty dois" do
      work = FactoryBot.create(:draft_work, doi: "")
      expect(Work.find_by_doi("")).to eq(work)
    end
  end

  describe "#find_by_ark" do
    let(:client_s3_files) { [] }
    let(:doi) { "ark:/88435/xyz123" }
    let(:work) { FactoryBot.create(:draft_work, ark: doi) }

    before do
      @ezid = doi
      stub_ark
      work # make sure the work is present
    end

    it "finds the work" do
      expect(Work.find_by_ark("ark:/88435/xyz123")).to eq(work)
      expect(Work.find_by_ark("88435/xyz123")).to eq(work)
    end

    it "does not find partial matches" do
      expect { Work.find_by_ark("ark:/88435/xyz12") }.to raise_error(ActiveRecord::RecordNotFound)
      expect { Work.find_by_ark("ark:/88435/xyz1234") }.to raise_error(ActiveRecord::RecordNotFound)
      expect { Work.find_by_ark("88435/xyz12") }.to raise_error(ActiveRecord::RecordNotFound)
      expect { Work.find_by_ark("88435/xyz1234") }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "can find nil arks" do
      Work.delete_all
      work2 = FactoryBot.create(:draft_work, ark: nil)
      expect(Work.find_by_ark(nil)).to eq(work2)
    end

    it "can find empty dois" do
      work3 = FactoryBot.create(:draft_work, ark: "")
      expect(Work.find_by_ark("")).to eq(work3)
    end
  end

  describe "#reload_snapshots" do
    let(:work) { FactoryBot.create(:draft_work) }
    let(:fake_s3_service) { stub_s3 }
    let(:file1) { FactoryBot.build :s3_file, filename: "file1.txt", last_modified: Time.parse("2022-04-21T18:29:40.000Z"), checksum: "test1" }
    let(:file2) { FactoryBot.build :s3_file, filename: "file2.txt", last_modified: Time.parse("2022-04-21T18:29:40.000Z"), checksum: "test2" }
    let(:new_file2) { FactoryBot.build :s3_file, filename: "file2.txt", last_modified: Time.parse("2022-04-21T19:29:40.000Z"), checksum: "test2_new" }

    before do
      allow(fake_s3_service).to receive(:client_s3_files).and_return([file1, file2], [file1, new_file2])
    end

    it "starts with nothing" do
      # shows a replaced file
      expect(work.upload_snapshots).to be_empty
      expect(work.work_activity).to be_empty
    end

    it "loads all the file changes in one snapshot and one work activity" do
      # shows a replaced file
      work.reload_snapshots
      expect(work.upload_snapshots.count).to eq(1)
      expect(work.upload_snapshots.first.files).to eq([{ "checksum" => "test1", "filename" => "file1.txt" },
                                                       { "checksum" => "test2", "filename" => "file2.txt" }])
      expect(work.work_activity.count).to eq(1)
      expect(work.work_activity.first.message).to eq('[{"action":"added","filename":"file1.txt","checksum":"test1"},{"action":"added","filename":"file2.txt","checksum":"test2"}]')

      # shows a replaced file
      work.reload_snapshots
      expect(work.upload_snapshots.count).to eq(2)
      expect(work.upload_snapshots.first.files).to eq([{ "checksum" => "test1", "filename" => "file1.txt" },
                                                       { "checksum" => "test2_new", "filename" => "file2.txt" }])
      expect(work.work_activity.count).to eq(2)
      expect(work.work_activity.first.message).to eq('[{"action":"replaced","filename":"file2.txt","checksum":"test2_new"}]')
    end

    context "when no changes occur" do
      before do
        allow(fake_s3_service).to receive(:client_s3_files).and_return([file1, file2])
        work.reload_snapshots
      end

      it "does not show changes when no changes occur" do
        expect(work.upload_snapshots.count).to eq(1)
        expect(work.work_activity.count).to eq(1)
        work_reload = Work.find(work.id) # making sure there is no instance caching
        work_reload.reload_snapshots
        expect(work.upload_snapshots.count).to eq(1)
        expect(work.work_activity.count).to eq(1)
      end
    end
  end
end
