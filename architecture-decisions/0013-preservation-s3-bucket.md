# 12. Document why and how we will be backing up data from postcuration to preservation s3 buckets

Date: 2023-??-??

## Status

Discussion

## Context

For preservation we need to have multiple copies of the files in the post curation bucket

## Decision

1. We will keep post curation and preservation buckets consistent.  This means if a file is added to the post curation bucket outside of PDC Describe it will automatically be copied to the preservation bucket.
2. We will utilize [Amazon Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html) to keep the buckets in synch.
3. We will utilize [Amazon Deletion Marker Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/delete-marker-replication.html) to make sure items deleted from the post-curation bucket are removed from preservation.

## Consequences

Files in the post-curation bucket will be duplicated to the preservation bucket via Amazon Replication.  The metadata in the preservation bucket will continue to be created by the PDCDescribe ruby code when the work is approved.  The provenance record will not necessarily reflect changes to the files after the work has been approved and move to post-curation.