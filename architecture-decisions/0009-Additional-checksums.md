# 9. Additional checksums from AWS S3 Storage

Date: 2023-05-22

## Status

Discussion

## Context

This research was done as part of the [PDC Describe preservation plan](https://docs.google.com/document/d/1PG2yQCdOAgKuEcXpX578ED6VCahmel1PRchOpi1hYwQ/edit#).

[Additional checksums](https://aws.amazon.com/blogs/aws/new-additional-checksum-algorithms-for-amazon-s3/) in addition to MD5 can be recorded for objects in S3 if enabled at upload.  Objects that have already been uploaded to S3 without additional checksums enabled must be copied out of and then back into the bucket in order for S3 to record an additional checksum.  There are suggested methods for retroactively enabling additional checksums for objects already uploaded to S3, and a lambda-based strategy for enabling them for all newly uploaded objects in [this article from AWS](https://aws.amazon.com/blogs/storage/enabling-and-validating-additional-checksums-on-existing-objects-in-amazon-s3/).  

Checksums can be retrieved with the aws-sdk Rubygem code, example call and output:

```ruby
pry(main)> s3_client = Aws::S3::Client.new
=> #<Aws::S3::Client>
pry(main)> s3_client.head_object({bucket: $BUCKET, key: $KEY, checksum_mode: "ENABLED"})
=> #<struct Aws::S3::Types::HeadObjectOutput
 delete_marker=nil,
 accept_ranges="bytes",
 expiration=nil,
 restore=nil,
 archive_status=nil,
 last_modified=2023-05-16 20:46:17 +0000,
 content_length=3223,
 checksum_crc32=nil,
 checksum_crc32c=nil,
 checksum_sha1=nil,
 checksum_sha256="eq+HYy2LJRt9zRB12oj/zfMHIZaOLL8PHvUn6h1UzRU=",
 etag="\"1e204dad3e9e1e2e6660eef9c33467e9\"",
 missing_meta=nil,
 version_id="L5f5q1wIbmSrRZ1yB_JjNLNwsc0AROhS",
 cache_control=nil,
 content_disposition=nil,
 content_encoding=nil,
 content_language=nil,
 content_type="text/plain",
 expires=nil,
 expires_string=nil,
 website_redirect_location=nil,
 server_side_encryption="AES256",
 metadata={},
 sse_customer_algorithm=nil,
 sse_customer_key_md5=nil,
 ssekms_key_id=nil,
 bucket_key_enabled=nil,
 storage_class=nil,
 request_charged=nil,
 replication_status=nil,
 parts_count=nil,
 object_lock_mode=nil,
 object_lock_retain_until_date=nil,
 object_lock_legal_hold_status=nil>
```

The response from the Rubygem mirrors the awscli head-object response, example: 

Call: 

```bash
aws s3api head-object --bucket $BUCKET --key $OBJECT_KEY --output json --checksum-mode ENABLED
```

Response:

```bash
{
    "AcceptRanges": "bytes",
    "LastModified": "2023-05-16T20:46:17+00:00",
    "ContentLength": 3223,
    "ChecksumSHA256": "eq+HYy2LJRt9zRB12oj/zfMHIZaOLL8PHvUn6h1UzRU=",
    "ETag": "\"1e204dad3e9e1e2e6660eef9c33467e9\"",
    "VersionId": "L5f5q1wIbmSrRZ1yB_JjNLNwsc0AROhS",
    "ContentType": "text/plain",
    "ServerSideEncryption": "AES256",
    "Metadata": {}
}
```

[This Python-based command line tool](https://github.com/aws-samples/amazon-s3-checksum-verification) from AWS can be used to verify that a local file stored has the same checksum as its counterpart in S3, example:

Call: 

```python
./integrity-check.py  --bucketName $BUCKET --objectName $KEY --localFileName $LOCAL_FILENAME
```

Output:

```bash
PASS: ChecksumSHA256 match! - s3Checksum: eq+HYy2LJRt9zRB12oj/zfMHIZaOLL8PHvUn6h1UzRU= | localChecksum: eq+HYy2LJRt9zRB12oj/zfMHIZaOLL8PHvUn6h1UzRU=
```

## Decisions

We will use MD5 checksums in PDC Describe.  However, as checksums can only be generated upon upload or by copying already-uploaded files out of and then back into their bucket, we will turn on SHA-256 checksums for all new objects in pre-curation and post-curation buckets for the MVP launch using the above-described lambda technique, monitor the financial impact of running the lambda, and will work leadership and stakeholders to determine the use cases for checksums beyond MD5.

## Consequences

AWS S3 will record and store the MD5 and SHA-256 checksums for all objects in PDC Describe.  MD5 checksums are [documented as being at higher risk for message collisions](https://www.section.io/engineering-education/what-is-md5/), and providing two checksums will allow us to do extra validation in the event of needing to validate that a file is intact.  Running a lambda on AWS S3 will incur a financial cost, which we will monitor and report on to leadership.
