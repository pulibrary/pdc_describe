# 9. Additional checksums from AWS S3 Storage

Date: 2023-05-22

## Status

Discussion

## Context

This research was done as part of the [PDC Describe preservation plan](https://docs.google.com/document/d/1PG2yQCdOAgKuEcXpX578ED6VCahmel1PRchOpi1hYwQ/edit#).

[Additional checksums](https://aws.amazon.com/blogs/aws/new-additional-checksum-algorithms-for-amazon-s3/) in addition to MD5 can be recorded for objects in S3 if enabled at upload.  There are suggested methods for retroactively enabling additional checksums for objects already uploaded to S3, and a lambda-based strategy for enabling them for all newly uploaded objects in [this article from AWS](https://aws.amazon.com/blogs/storage/enabling-and-validating-additional-checksums-on-existing-objects-in-amazon-s3/).

Based on preliminary exploration, additional checksums do not appear to be available via the aws-sdk Rubygem’s code, despite the fact that there are instance methods referencing them, example:

Call and output on an object with the SHA-256 checksum set:

```ruby
pry(main)> object.checksum_sha256
=> nil
```

The checksums can be retrieved in the head-object response from the API, example: 

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

This Python-based command line tool from AWS can be used to verify that a local file stored has the same checksum as its counterpart in S3, example:

Call: 

```python
./integrity-check.py  --bucketName $BUCKET --objectName $KEY --localFileName $LOCAL_FILENAME
```

Output:

```bash
PASS: ChecksumSHA256 match! - s3Checksum: eq+HYy2LJRt9zRB12oj/zfMHIZaOLL8PHvUn6h1UzRU= | localChecksum: eq+HYy2LJRt9zRB12oj/zfMHIZaOLL8PHvUn6h1UzRU=
```

## Decisions

We will use MD5 checksums in PDC Describe, but document the method(s) for enabling verifying against additional checksums, should we decide to use these methods in the future.

## Consequences

We are only guaranteed to be recording the MD5 checksum for each file in PDC Describe.  MD5 checksums are [documented as being at higher risk for message collisions](https://www.section.io/engineering-education/what-is-md5/) however we consider this an acceptable risk at this time due to the volume of deposits that we anticipate PDC receiving, plus the additional checksums can only be beneficial in the event that we have what we believe to be an intact local copy of a file that we wish to verify against whatever is stored in S3.  This does not match our disaster recovery scenario.
