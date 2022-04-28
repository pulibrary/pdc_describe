# frozen_string_literal: true
require "rails_helper"

RSpec.describe S3QueryService do
  let(:subject) { described_class.new(doi) }
  let(:s3_hash) do
    {
      contents: [
        {
          etag: "\"008eec11c39e7038409739c0160a793a\"",
          key: "10-34770/pe9w-x904/SCoData_combined_v1_2020-07_README.txt",
          last_modified: Time.parse("2022-04-21T18:29:40.000Z"),
          size: 10_759,
          storage_class: "STANDARD"
        },
        {
          etag: "\"7bd3d4339c034ebc663b990657714688\"",
          key: "10-34770/pe9w-x904/SCoData_combined_v1_2020-07_datapackage.json",
          last_modified: Time.parse("2022-04-21T18:30:07.000Z"),
          size: 12_739,
          storage_class: "STANDARD"
        }
      ]
    }
  end

  # DOI for Shakespeare and Company Project Dataset: Lending Library Members, Books, Events
  # https://dataspace.princeton.edu/handle/88435/dsp01zc77st047
  let(:doi) { "https://doi.org/10.34770/pe9w-x904" }

  it "knows the name of its s3 bucket" do
    expect(subject.bucket_name).to eq "pdc-describe-test1"
  end

  it "converts a doi to an S3 address" do
    expect(subject.s3_address).to eq "s3://pdc-describe-test1/10-34770/pe9w-x904"
  end

  it "takes a DOI and returns information about that DOI in S3" do
    fake_aws_client = double(Aws::S3::Client)
    subject.stub(:client).and_return(fake_aws_client)
    fake_s3_resp = double(Aws::S3::Types::ListObjectsV2Output)
    fake_aws_client.stub(:list_objects_v2).and_return(fake_s3_resp)
    fake_s3_resp.stub(:to_h).and_return(s3_hash)

    data_profile = subject.data_profile
    expect(data_profile).to be_instance_of(Array)
    expect(data_profile.count).to eq 2
    expect(data_profile.first).to be_instance_of(S3File)
    expect(data_profile.first.filename).to match(/README/)
    expect(data_profile.first.last_modified).to eq Time.parse("2022-04-21T18:29:40.000Z")
    expect(data_profile.first.size).to eq 10_759
  end

  describe "#client" do
    before do
      allow(Aws::S3::Client).to receive(:new)
      subject.client
    end

    it "constructs the AWS S3 API client object" do
      expect(Aws::S3::Client).to have_received(:new).with(region: "us-east-1")
    end
  end
end
