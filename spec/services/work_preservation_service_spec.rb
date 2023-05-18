# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkPreservationService do
  describe "#preserve!" do
    let(:approved_work) { FactoryBot.create :approved_work, doi: "10.34770/pe9w-x904" }
    let(:bucket_name) { approved_work.s3_query_service.bucket_name }
    let(:path) { approved_work.s3_query_service.prefix }
    let(:preservation_directory) { path + "princeton_data_commons/" }

    before do
      stub_request(:put, "https://example-bucket-post.s3.amazonaws.com/#{preservation_directory}").to_return(status: 200)
      stub_request(:get, "https://example-bucket-post.s3.amazonaws.com/?list-type=2&max-keys=1000&prefix=#{path}").to_return(status: 200)
      stub_request(:put, "https://example-bucket-post.s3.amazonaws.com/#{preservation_directory}metadata.json").to_return(status: 200)
      stub_request(:put, "https://example-bucket-post.s3.amazonaws.com/#{preservation_directory}datacite.xml").to_return(status: 200)
    end

    it "preserves a work to the indicated location" do
      subject = described_class.new(work_id: approved_work.id, bucket_name: bucket_name, path: path)
      expect(subject.preserve!).to eq "s3://example-bucket-post/#{preservation_directory}"
    end
  end
end
