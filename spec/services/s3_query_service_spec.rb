# frozen_string_literal: true
require "rails_helper"

RSpec.describe S3QueryService, mock_s3_query_service: false do
  let(:work) { FactoryBot.create :draft_work, doi: doi }
  let(:subject) { described_class.new(work) }
  let(:s3_key1) { "10-34770/pe9w-x904/SCoData_combined_v1_2020-07_README.txt" }
  let(:s3_key2) { "10-34770/pe9w-x904/SCoData_combined_v1_2020-07_datapackage.json" }
  let(:s3_last_modified1) { Time.parse("2022-04-21T18:29:40.000Z") }
  let(:s3_last_modified2) { Time.parse("2022-04-21T18:30:07.000Z") }
  let(:s3_size1) { 10_759 }
  let(:s3_size2) { 12_739 }
  let(:s3_hash) do
    {
      contents: [
        {
          etag: "\"008eec11c39e7038409739c0160a793a\"",
          key: s3_key1,
          last_modified: s3_last_modified1,
          size: s3_size1,
          storage_class: "STANDARD"
        },
        {
          etag: "\"7bd3d4339c034ebc663b990657714688\"",
          key: s3_key2,
          last_modified: s3_last_modified2,
          size: s3_size2,
          storage_class: "STANDARD"
        },
        {
          etag: "\"7bd3d4339c034ebc663b99065771111\"",
          key: "A directory",
          last_modified: s3_last_modified2,
          size: 0,
          storage_class: "STANDARD"
        }
      ]
    }
  end

  # DOI for Shakespeare and Company Project Dataset: Lending Library Members, Books, Events
  # https://dataspace.princeton.edu/handle/88435/dsp01zc77st047
  let(:doi) { "10.34770/pe9w-x904" }

  it "knows the name of its s3 bucket" do
    expect(subject.bucket_name).to eq "example-bucket"
  end

  it "converts a doi to an S3 address" do
    expect(subject.s3_address).to eq "s3://example-bucket/10.34770/pe9w-x904/#{work.id}/"
  end

  it "takes a DOI and returns information about that DOI in S3" do
    fake_aws_client = double(Aws::S3::Client)
    subject.stub(:client).and_return(fake_aws_client)
    fake_s3_resp = double(Aws::S3::Types::ListObjectsV2Output)
    fake_aws_client.stub(:list_objects_v2).and_return(fake_s3_resp)
    fake_s3_resp.stub(:to_h).and_return(s3_hash)

    data_profile = subject.data_profile
    expect(data_profile[:objects]).to be_instance_of(Array)
    expect(data_profile[:ok]).to eq true
    expect(data_profile[:objects].count).to eq 2
    expect(data_profile[:objects].first).to be_instance_of(S3File)
    expect(data_profile[:objects].first.filename).to match(/README/)
    expect(data_profile[:objects].first.last_modified).to eq Time.parse("2022-04-21T18:29:40.000Z")
    expect(data_profile[:objects].first.size).to eq 10_759
  end

  it "handles connecting to a bad bucket" do
    fake_aws_client = Aws::S3::Client
    subject.stub(:client).and_return(fake_aws_client)
    data_profile = subject.data_profile
    expect(data_profile[:objects]).to be_instance_of(Array)
    expect(data_profile[:ok]).to eq false
  end

  describe ".url_protocol" do
    it "accesses the protocol for the S3 Bucket URL" do
      expect(described_class.url_protocol).to eq("https")
    end
  end

  describe ".s3_host" do
    it "accesses the host for the S3 Bucket URL" do
      expect(described_class.s3_host).to eq("s3.amazonaws.com")
    end
  end

  describe "#client" do
    before do
      allow(Aws::S3::Client).to receive(:new)
      subject.client
    end

    it "constructs the AWS S3 API client object" do
      expect(Aws::S3::Client).to have_received(:new).with(hash_including(region: "us-east-1")).at_least(:once)
    end
  end

  context "with persisted Works" do
    let(:user) { FactoryBot.create(:user) }
    let(:doi) { "10.34770/doc-1" }
    let(:work) { FactoryBot.create(:draft_work, doi: doi) }
    let(:uploaded_file) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end
    let(:uploaded_file2) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end
    let(:attachment_url) { "https://example-bucket.s3.amazonaws.com/#{doi}/" }
    let(:fake_aws_client) { double(Aws::S3::Client) }

    before do
      Collection.create_defaults
      user

      stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
      stub_request(:put, /#{attachment_url}/).to_return(status: 200)

      work.pre_curation_uploads.attach(uploaded_file)
      work.pre_curation_uploads.attach(uploaded_file2)
      work

      subject.stub(:client).and_return(fake_aws_client)
      fake_s3_resp = double(Aws::S3::Types::ListObjectsV2Output)
      fake_aws_client.stub(:list_objects_v2).and_return(fake_s3_resp)
      fake_s3_resp.stub(:to_h).and_return(s3_hash)
    end

    describe "#publish_files" do
      it "calls S3 copy_object twice, once for each file" do
        s3_stub = Aws::S3::Client.new(stub_responses: true)
        subject.stub(:client).and_return(s3_stub)
        allow(subject.client).to receive(:copy_object)
        subject.publish_files
        expect(subject.client).to have_received(:copy_object).twice
      end
    end

    describe "#data_profile" do
      context "when an error is encountered requesting the file resources" do
        let(:output) { subject.data_profile }

        before do
          fake_aws_client.stub(:list_objects_v2).and_raise(StandardError)
          allow(Rails.logger).to receive(:error)
          output
        end

        it "an error is logged" do
          expect(Rails.logger).to have_received(:error).with("Error querying S3. Bucket: example-bucket. DOI: #{doi}. Exception: StandardError")
          expect(output).to eq({ objects: [], ok: false })
        end
      end

      it "takes a DOI and returns information about that DOI in S3" do
        data_profile = subject.data_profile
        expect(data_profile).to be_a(Hash)
        expect(data_profile).to include(:objects)
        children = data_profile[:objects]

        expect(children.count).to eq 2
        expect(children.first).to be_instance_of(S3File)
        expect(children.first.filename).to eq(s3_key1)

        last_modified = children.first.last_modified
        expect(last_modified.to_s).to eq(s3_last_modified1.to_s)

        expect(children.first.size).to eq(s3_size1)

        expect(children.last).to be_instance_of(S3File)
        expect(children.last.filename).to eq(s3_key2)

        last_modified = children.last.last_modified
        expect(last_modified.to_s).to eq(s3_last_modified2.to_s)

        expect(children.last.size).to eq(s3_size2)
      end
    end
  end

  context "post curated" do
    let(:subject) { described_class.new(work, false) }

    it "keeps precurated and post curated items separate" do
      fake_aws_client = double(Aws::S3::Client)
      subject.stub(:client).and_return(fake_aws_client)
      fake_s3_resp = double(Aws::S3::Types::ListObjectsV2Output)
      fake_aws_client.stub(:list_objects_v2).and_return(fake_s3_resp)
      fake_s3_resp.stub(:to_h).and_return(s3_hash)

      blob = ActiveStorage::Blob.new(filename: s3_key1, key: s3_key1, content_type: "", byte_size: 100, checksum: "abc123")
      work.pre_curation_uploads << ActiveStorage::Attachment.new(blob: blob, name: :pre_curation_uploads)

      data_profile = subject.data_profile
      expect(data_profile[:objects]).to be_instance_of(Array)
      expect(data_profile[:ok]).to eq true
      expect(data_profile[:objects].count).to eq 2
      expect(data_profile[:objects].first).to be_instance_of(S3File)
      expect(data_profile[:objects].first.filename).to match(/README/)
      expect(data_profile[:objects].first.last_modified).to eq Time.parse("2022-04-21T18:29:40.000Z")
      expect(data_profile[:objects].first.size).to eq 10_759
    end
  end
  let(:response_headers) do
    {
      'Accept-Ranges': "bytes",
      'Content-Length': 12,
      'Content-Type': "text/plain",
      'ETag': "6805f2cfc46c0f04559748bb039d69ae",
      'Last-Modified': Time.parse("Thu, 15 Dec 2016 01:19:41 GMT")
    }
  end

  describe "#get_s3_object" do
    subject(:s3_query_service) { described_class.new(work) }
    let(:key) { "test_key" }
    let(:s3_object) { s3_query_service.get_s3_object(key: key) }

    before do
      stub_request(:get, "https://example-bucket.s3.amazonaws.com/test_key").to_return(status: 200, body: "test_content", headers: response_headers)
    end

    it "retrieves the S3 Object from the HTTP API" do
      expect(s3_object).not_to be nil
      bytestream = s3_object[:body]
      expect(bytestream.read).to eq("test_content")
    end
  end

  describe "#find_s3_file" do
    subject(:s3_query_service) { described_class.new(work) }
    let(:filename) { "test.txt" }
    let(:s3_file) { s3_query_service.find_s3_file(filename: filename) }

    it "retrieves the S3File from the AWS Bucket" do
      expect(s3_file).not_to be nil

      expect(s3_file.filename).to eq("10.34770/pe9w-x904/#{work.id}/test.txt")
      expect(s3_file.last_modified).to be_a(Time)
      expect(s3_file.size).to eq(12)
      expect(s3_file.checksum).to eq("6805f2cfc46c0f04559748bb039d69ae")
    end
  end
end
