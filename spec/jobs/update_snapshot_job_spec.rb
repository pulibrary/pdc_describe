# frozen_string_literal: true
require "rails_helper"

RSpec.describe UpdateSnapshotJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { FactoryBot.create :user }

  let(:s3_file) { FactoryBot.build :s3_file, work:, filename: "#{work.prefix}/test_key" }

  describe "perform" do
    subject(:job) do
      described_class.perform_later(work_id: work.id, last_snapshot_id: nil)
    end
    let(:fake_s3_service) { stub_s3 prefix: "10.34770/ackh-7y71/#{work.id}", data: [s3_file] }
    let(:work) { FactoryBot.create :approved_work, doi: "10.34770/ackh-7y71" }

    before do
      fake_s3_service
    end

    it "creates an upload snapshot" do
      expect { perform_enqueued_jobs { job } }.to change { UploadSnapshot.count }.by(1)
    end

    context "when last snapshot is different" do
      subject(:job) do
        described_class.perform_later(work_id: work.id, last_snapshot_id: 123)
      end

      it "skips processing" do
        expect { perform_enqueued_jobs { job } }.to change { UploadSnapshot.count }.by(0)
      end
    end
  end
end
