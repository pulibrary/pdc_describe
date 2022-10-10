# 3. Data Storage and the Curation Station

Date: 2022-08-01

## Status

Discussion

## Context

Researchers need access to our Globus pre-curation endpoint to deposit their large datasets. We also need to keep post-curation data secure from modification. We are utilizing two s3 buckets, one for pre-curation and one for post-curation data.

## Decisions

- We will make the pre-curation s3 bucket private and allow access for deposit only via Globus
- We will make the pre-curation bucket accessible for read and write via a Globus guest collection with public Read/Write to any user.
- We will make the post-curation s3 bucket private to only allow curators and systems write to access the data.
- We will make the post-curation s3 bucket accessible via Globus to the public utilizing a Globus Guest Collection with Read only access permissions.

## Consequences

- IAM users and access keys will only be generated for the post-curation s3 bucket
- We will need two Globus Endpoints each with a second guest collection for public access
- The pre-curation s3 bucket is not available for modification by anyone except administrators or folks who access it via Globus
