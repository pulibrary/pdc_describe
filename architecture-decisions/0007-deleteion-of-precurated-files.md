# 7. S3 files are deleted when files are deleted in the system

Date: 2022-10-13

## Status

Decided

## Context

The system allows for files in the pre-curation S3 bucket to be deleted by the user from the User Interface (UI).
These files may or may not have been deposited via the UI.  They could have also been deposited via Globus or directly via S3.

When files are deleted from S3 in a bucket that is not versioned they can not be recovered.  When files are deleted from an S3 bucket that is versioned then files can be recovered via the [S3 console](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ManagingDelMarkers.html).

## Decisions

* In pre-curation, the system does not distinguish how the files were deposited and will allow the ability to delete all files via the UI.
* We will turn on versioning in the S3 buckets so files can be recovered if deleted in error.
* We will permanently delete files in S3 after 30 days via a [lifecycle configuration rule](https://docs.aws.amazon.com/AmazonS3/latest/userguide/how-to-set-lifecycle-configuration-intro.html)

## Consequences

* Files no matter how they are deposited can be deleted by the depositor, the collection curators, and the administrators via the UI.
* Deleted files can be recovered via the S3 console up to 29 days after they are deleted
* We will be storing deleted content in S3 for 30 days, which will incur a cost.
