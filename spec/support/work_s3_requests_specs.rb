# frozen_string_literal: true

RSpec.configure do |_config|
  def build_s3_list_objects_response(work:, file_name:)
    @s3_list_objects_response = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Name>example-bucket</Name>
  <Prefix/>
  <KeyCount>1</KeyCount>
  <MaxKeys>1000</MaxKeys>
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>#{work.s3_object_key}/#{file_name}</Key>
    <LastModified>2009-10-12T17:50:30.000Z</LastModified>
    <ETag>"fba9dede5f27731c9771645a39863328"</ETag>
    <Size>434234</Size>
    <StorageClass>STANDARD</StorageClass>
  </Contents>
</ListBucketResult>
XML
  end

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/MethodLength
  def stub_work_s3_requests(works: [], work: nil, file_name: nil)
    # Use the built-in AWS S3 stub
    # (https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/stubbing.html)
    s3 = Aws::S3::Client.new(stub_responses: true)
    allow(Aws::S3::Client).to receive(:new).and_return(s3)
    s3.stub_responses(:head_object, [Aws::S3::Errors::NotFound.new("1", "2"), true])

    @works = if work.nil?
               works
             else
               [work]
             end

    @works.each do |w|
      ## Implicit context: S3 Bucket exists for a pre-curation Work
      # Stub the request for the S3 directory object to determine if it exists (pre-curation bucket)
      stub_request(:head, "https://example-bucket.s3.amazonaws.com/#{w.s3_object_key}").to_return(status: 200)

      ## Implicit context: S3 Bucket exists for a pre-curation Work, Work is being updated into the post-curation state
      # Stub the request for the S3 directory object to determine if it exists (post-curation)
      stub_request(:head, "https://example-bucket-post.s3.amazonaws.com/#{w.s3_object_key}").to_return(status: 404)
      # Stub the request to delete the S3 directory object to determine if it exists (pre-curation bucket)
      stub_request(:delete, "https://example-bucket.s3.amazonaws.com/#{w.s3_object_key}").to_return(status: 200)

      # Build the request body for the request to query the contents of the S3 directory object
      # By default, this is empty
      s3_list_objects_response = []

      unless file_name.nil?
        ## Implicit context: S3 Bucket exists for a pre-curation Work, the Work has one S3 file attachment Object stored
        # Stub the request for retrieving the S3 file attachment object
        stub_request(:get, "https://example-bucket.s3.amazonaws.com/#{w.s3_object_key}/#{file_name}").to_return(status: 200)
        # Stub the request for uploading the S3 file attachment object
        stub_request(:put, "https://example-bucket.s3.amazonaws.com/#{w.s3_object_key}/#{file_name}").to_return(status: 200)
        # Build the request body for the request to query the contents of the S3 directory object
        s3_list_objects_response = build_s3_list_objects_response(work: w, file_name: file_name)
      end

      ## Implicit context: S3 Bucket exists for a pre-curation Work, the Work has one S3 file attachment Object stored
      # Stub the pre-curation bucket list
      stub_request(:get, "https://example-bucket.s3.amazonaws.com/?list-type=2&max-keys=1000&prefix=#{w.s3_object_key}/").to_return(
        status: 200,
        body: s3_list_objects_response
      )

      ## Implicit context: S3 Bucket exists for a post-curation Work, the Work has one S3 file attachment Object stored
      # Stub the post-curation bucket list
      stub_request(:get, "https://example-bucket-post.s3.amazonaws.com/?list-type=2&max-keys=1000&prefix=#{w.s3_object_key}/").to_return(
        status: 200,
        body: s3_list_objects_response
      )

      next if file_name.nil?
      # Stub the request for retrieving the S3 file attachment object
      stub_request(:get, "https://example-bucket-post.s3.amazonaws.com/#{w.s3_object_key}/#{file_name}").to_return(
        status: 200,
        body: {
          accept_ranges: "bytes",
          content_length: 3191,
          content_type: "image/jpeg",
          etag: "\"6805f2cfc46c0f04559748bb039d69ae\"",
          last_modified: Time.parse("Thu, 15 Dec 2016 01:19:41 GMT"),
          metadata: {
          },
          tag_count: 2,
          version_id: "null"
        }.to_json
      )
      # Stub the request for the S3 directory object to determine if it exists (post-curation)
      stub_request(:head, "https://example-bucket-post.s3.amazonaws.com/#{w.s3_object_key}/#{file_name}").to_return(status: 200)

      # Stub the request to delete the S3 file object (pre-curation bucket)
      stub_request(:delete, "https://example-bucket.s3.amazonaws.com/#{w.s3_object_key}/#{file_name}").to_return(status: 200)
    end
    # rubocop:enable Metrics/AbcSize
  end
end
