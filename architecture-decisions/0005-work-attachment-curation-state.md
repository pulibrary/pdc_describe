# 5. Determine the storage service for `Work` file attachments

Date: 2022-08-30

## Status

Decided

## Context

Ambiguity exists for cases in which users upload file as S3 Objects within Amazon Web Service S3 Buckets prior to a new `Work` being created within PDC Describe, and for cases in which there are files uploaded and attached to an existing `Work` as ActiveStorage attachments (using the file upload form within the PDC Describe application). Further, once a `Work` is considered to be `post-curation`, it is unclear as to whether or not files attached during the `pre-curation` state should be managed separately from S3 Objects, if S3 Objects which are not ActiveStorage attachments should be synchronized as such, or if ActiveStorage attachments should be synchronized from ActiveStorage attachments as new S3 Objects within the `curation` Bucket.

## Decisions

* `Work` objects which are in the `pre-curation` state should have all existing S3 Bucket Objects synchronized as new ActiveStorage attachments, these attachments should be persisted, and the S3 Bucket Objects do *not* need to be deleted. These `ActiveStorage` attachments will persist their binary bitstream using a file system.
* `Work` objects which are advanced to the `post-curation` state should have all existing ActiveStorage attachments synchronized to the `post-curation` S3 Bucket as new Bucket Objects, *without* the usage of the `ActiveStorage` API. The existing ActiveStorage attachments for `Works` in the the `post-curation` state should be deleted. These new S3 Bucket Objects will use the Amazon S3 service client to persist the binary bitstream while still using the Rails ActiveStorage APIs for consistency.

## Consequences

* Directly uploading S3 Bucket Objects will no longer be the preferred method of attaching files to a `Work` in the `pre-curation` state.
* `Works` advanced to the `post-curation` state will require the application to use ActiveStorage consistently but with a separate, dedicated storage service (for uploads to the S3 Bucket).
* Advancing `Works` to the `post-curation` state will require that the S3 Bucket for `post-curation` S3 Objects be created in response to an update in the state of the `Work` object.
* Having `post-curation` S3 Objects managed without using the ActiveStorage API with not preserve the order of the `post-curation` S3 Objects.
