# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkPreservationService do
  let(:draft_work) { FactoryBot.create :draft_work, doi: "10.34770/pe9w-x904" }

  it "raises an exception if the work has not been approved" do
    subject = described_class.new(work: draft_work)
    expect { subject.preserve! }.to raise_error(StandardError, /Cannot preserve work/)
  end

  describe "preserves to default location" do
    let(:approved_work) { FactoryBot.create :approved_work, doi: "10.34770/pe9w-x904" }
    let(:prefix) { approved_work.s3_query_service.prefix }
    let(:preservation_directory) { prefix + "princeton_data_commons/" }

    before do
      stub_request(:put, "https://example-bucket-post.s3.amazonaws.com/#{preservation_directory}").to_return(status: 200)
      stub_request(:get, "https://example-bucket-post.s3.amazonaws.com/?list-type=2&max-keys=1000&prefix=#{prefix}").to_return(status: 200)
      stub_request(:put, "https://example-bucket-post.s3.amazonaws.com/#{preservation_directory}metadata.json").to_return(status: 200)
      stub_request(:put, "https://example-bucket-post.s3.amazonaws.com/#{preservation_directory}datacite.xml").to_return(status: 200)
    end

    it "preserves a work to the default location" do
      subject = described_class.new(work: approved_work)
      expect(subject.preserve!).to eq "s3://example-bucket-post/#{preservation_directory}"
    end
  end

  describe "preserve to custom location" do
    let(:approved_work) { FactoryBot.create :approved_work, doi: "10.34770/pe9w-x904" }

    before do
      stub_request(:put, "https://custom-bucket.s3.amazonaws.com/custom/path/princeton_data_commons/").to_return(status: 200)
      stub_request(:get, "https://example-bucket-post.s3.amazonaws.com/?list-type=2&max-keys=1000&prefix=#{approved_work.s3_query_service.prefix}").to_return(status: 200)
      stub_request(:put, "https://custom-bucket.s3.amazonaws.com/custom/path/princeton_data_commons/metadata.json").to_return(status: 200)
      stub_request(:put, "https://custom-bucket.s3.amazonaws.com/custom/path/princeton_data_commons/datacite.xml").to_return(status: 200)
    end

    it "preserves a work to the default location" do
      subject = described_class.new(work: approved_work, bucket_name: "custom-bucket", path: "custom/path/")
      expect(subject.preserve!).to eq "s3://custom-bucket/custom/path/princeton_data_commons/"
    end
  end
end
