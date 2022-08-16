# frozen_string_literal: true
require "rails_helper"

RSpec.describe S3QueryService, mock_ezid_api: true do
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
    expect(subject.bucket_name).to eq "example-bucket"
  end

  context "with persisted Works" do
    let(:user) { FactoryBot.create(:user) }
    let(:curator) { FactoryBot.create(:user) }
    let(:collection) { Collection.first }
    let(:resource) { FactoryBot.build :resource }
    let(:work) do
      Work.create_dataset(user.id, collection.id, resource)
    end
    let(:doi) { "10.34770/doc-1" }
    let(:uploaded_file) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end
    let(:uploaded_file2) do
      fixture_file_upload("us_covid_2019.csv", "text/csv")
    end
    let(:attachment_url) { "https://example-bucket.s3.amazonaws.com/#{doi}/" }

    before do
      Collection.create_defaults
      user

      stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: "10.34770"))
      stub_request(:put, /#{attachment_url}/).to_return(status: 200)

      work.pre_curation_uploads.attach(uploaded_file)
      work.pre_curation_uploads.attach(uploaded_file2)
      work

      fake_s3_resp = double(Aws::S3::Types::ListObjectsV2Output)
      fake_s3_resp.stub(:to_h).and_return(s3_hash)
    end

    describe "#data_profile" do
      context "when an error is encountered requesting the file resources" do
        let(:output) { subject.data_profile }

        before do
          allow(Rails.logger).to receive(:error)
          allow(Work).to receive(:find_by).and_raise(StandardError)

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
        expect(children.first.filename).to eq(work.pre_curation_uploads.first.key)

        last_modified = children.first.last_modified
        created_at = work.pre_curation_uploads.first.created_at
        expect(last_modified.to_s).to eq(created_at.to_s)

        expect(children.first.size).to eq(work.pre_curation_uploads.first.byte_size)
      end
    end
  end
end
