# 6. Determine the storage service for `Work` file attachments

Date: 2022-08-30

## Status

Decided

## Context

Should we store post-curation objects as ActiveStorage Objects or not?

In pre-curation, files uploaded via the form are ActiveStorage objects. Files can also be uploaded directly to S3, in which case we generate an ActiveStorage object for them. Do we want to have ActiveStorage objects in post-curation?

There are two separate S3 buckets, pre-curation and post-curation.

## Decisions

- `Work` objects which are in the `pre-curation` state should have all existing S3 Bucket Objects synchronized as new ActiveStorage attachments. This just makes an object in the database that points at that S3 file. The S3 bucket is not modified.
- `Work` objects which are advanced to the `post-curation` state should have all existing ActiveStorage attachments synchronized to the `post-curation` S3 Bucket as new Bucket Objects, _without_ the usage of the `ActiveStorage` API. The existing ActiveStorage attachments (i.e., the database record) for `Works` in the the `post-curation` state should be deleted.
- In summary, we will NOT use ActiveStorage for post-curated data.

## Consequences

- `Works` in the `pre-curation` state will have ActiveStorage records
- Advancing `Works` to the `post-curation` state will trigger a move of the relevant files to the post-curation S3 bucket
- Consistent with S3 and globus, there is no concept of order of files in file systems. That means we can't show files in a specific order in either S3 or Globus.
