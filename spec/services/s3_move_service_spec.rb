# frozen_string_literal: true
require "rails_helper"

RSpec.describe S3MoveService do
  describe "#move" do
    let(:fake_completion) { build_fake_s3_completion }

    let(:s3_file) { FactoryBot.build :s3_file, work:, filename: "#{work.prefix}/test_key" }

    subject(:move_service) do
      described_class.new(work_id: work.id, source_bucket: "example-bucket", source_key: s3_file.key, target_bucket: "example-bucket-post",
                          target_key: s3_file.key, size: 200)
    end
    let(:fake_s3_service) { stub_s3 prefix: "10.34770/ackh-7y71/#{work.id}" }
    let(:work) { FactoryBot.create :approved_work, doi: "10.34770/ackh-7y71" }

    before do
      allow(fake_s3_service).to receive(:copy_file).and_return(fake_completion)
      allow(fake_s3_service).to receive(:check_file).and_return(true)
      allow(fake_s3_service).to receive(:delete_s3_object).and_return(fake_completion)
    end

    it "runs an aws copy, check and then delete" do
      move_service.move
      expect(fake_s3_service).to have_received(:copy_file).with(size: 200, source_key: "example-bucket/#{s3_file.key}",
                                                                target_bucket: "example-bucket-post", target_key: s3_file.key)
      expect(fake_s3_service).to have_received(:check_file).with(bucket: "example-bucket-post", key: s3_file.key)
      expect(fake_s3_service).to have_received(:delete_s3_object).with(s3_file.key, bucket: "example-bucket")
    end

    context "the copy fails" do
      let(:fake_completion) { instance_double(Seahorse::Client::Response, "successful?": false) }

      before do
        allow(fake_s3_service).to receive(:copy_file).and_return(fake_completion)
      end
      it "runs an aws copy, but no delete" do
        expect { move_service.move }.to raise_error(/Error copying example-bucket\/10.34770\/ackh-7y71\/#{work.id}\/test_key to example-bucket-post\/10.34770\/ackh-7y71\/#{work.id}\/test_key/)
        expect(fake_s3_service).to have_received(:copy_file).with(size: 200, source_key: "example-bucket/#{s3_file.key}",
                                                                  target_bucket: "example-bucket-post", target_key: s3_file.key)
        expect(fake_s3_service).not_to have_received(:delete_s3_object).with("example-bucket/#{s3_file.key}")
        expect(fake_s3_service).not_to have_received(:delete_s3_object).with(work.s3_object_key, bucket: "example-bucket")
      end
    end

    context "the original key is missing" do
      before do
        allow(fake_s3_service).to receive(:copy_file).and_raise(Aws::S3::Errors::NoSuchKey.new(nil, nil))
        allow(fake_s3_service).to receive(:check_file).and_return(false)
      end
      it "runs an aws copy, but no delete" do
        expect { move_service.move }.to raise_error(/Missing source file example-bucket\/10.34770\/ackh-7y71\/#{work.id}\/test_key can not copy/)
        expect(fake_s3_service).to have_received(:copy_file).with(size: 200, source_key: "example-bucket/#{s3_file.key}",
                                                                  target_bucket: "example-bucket-post", target_key: s3_file.key)
        expect(fake_s3_service).not_to have_received(:delete_s3_object).with("example-bucket/#{s3_file.key}")
        expect(fake_s3_service).not_to have_received(:delete_s3_object).with(work.s3_object_key, bucket: "example-bucket")
      end
    end

    context "the file has a diacritic in the name" do
      let(:s3_file) { FactoryBot.build :s3_file, work:, filename: "#{work.prefix}/test_key é" }

      it "runs an aws copy, check and then delete" do
        move_service.move
        expect(fake_s3_service).to have_received(:copy_file).with(size: 200, source_key: "example-bucket/#{s3_file.key}",
                                                                  target_bucket: "example-bucket-post", target_key: s3_file.key)
        expect(fake_s3_service).to have_received(:check_file).with(bucket: "example-bucket-post", key: s3_file.key)
        expect(fake_s3_service).to have_received(:delete_s3_object).with(s3_file.key, bucket: "example-bucket")
      end
    end
  end
end
