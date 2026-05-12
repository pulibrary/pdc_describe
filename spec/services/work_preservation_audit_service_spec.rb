# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkPreservationAuditService do
  describe "audit preserve S3" do
    let(:work) { FactoryBot.create :approved_work, doi: "10.34770/pe9w-x904" }
    let(:path) { work.s3_query_service.prefix }
    let(:preservation_directory) { path + "princeton_data_commons/" }
    let(:file1) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/anyfile1_readme.txt", last_modified: Time.parse("2022-04-21T18:29:40.000Z") }
    let(:file2) { FactoryBot.build :s3_file, filename: "#{work.doi}/#{work.id}/folder1/anyfile2.txt", last_modified: Time.parse("2022-04-21T18:29:40.000Z") }
    let(:preservation_file1) do
      FactoryBot.build(
        :s3_file,
        filename: "#{work.doi}/#{work.id}//princeton_data_commons/metadata.json",
        last_modified: Time.parse("2022-04-21T18:29:40.000Z")
      )
    end
    let(:files) { [file1, file2, preservation_file1] }
    let(:fake_s3_service) { stub_s3(data: files, bucket_name: "example-bucket-preservation", prefix: "10.34770/pe9w-x904/#{work.id}/") }

    before do
      # Add the approval work activity, since the factory does not
      curator_user = FactoryBot.create :user, groups_to_admin: [work.group]
      WorkActivity.add_work_activity(work.id, "marked as #{work.state.to_s.titleize}", curator_user.id, activity_type: WorkActivity::SYSTEM)
      allow(fake_s3_service).to receive(:directory_empty).and_return(false)
    end

    it "audits that a work has been stored in the correct preservation bucket in S3" do
      subject = described_class.new(date: Time.zone.today)
      expect(subject.audit!).to be_truthy
      expect(fake_s3_service).to have_received(:directory_empty).with(key: "10.34770/pe9w-x904/#{work.id}/", bucket: "example-bucket-preservation")
    end

    it "returns true if no works were approved that day" do
      subject = described_class.new
      expect(subject.audit!).to be_truthy
      expect(fake_s3_service).not_to have_received(:directory_empty).with(key: "10.34770/pe9w-x904/#{work.id}/", bucket: "example-bucket-preservation")
    end

    context "when the directory is empty" do
      before do
        allow(Honeybadger).to receive(:notify)
        allow(fake_s3_service).to receive(:directory_empty).and_return(true)
      end
      it "audits that a work has not been stored in the correct preservation bucket in S3" do
        subject = described_class.new(date: Time.zone.today)
        expect { subject.audit! }.to raise_error(WorkAuditError, "Works Missing from preservation: <a href=\"http://www.example.com/works/#{work.id}\">#{work.title} (10.34770/pe9w-x904)</a>")
        expect(fake_s3_service).to have_received(:directory_empty).with(key: "10.34770/pe9w-x904/#{work.id}/", bucket: "example-bucket-preservation")
      end
    end
  end
end
