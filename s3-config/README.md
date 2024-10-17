# AWS configuration

## Lifecycle rules
S3 lifecycle rules help to keep the S3 buckets free from cruft, from files that have been deleted, many versions of files, and old log files.  The files in this directory can be applied to S3 using the aws command line client.  The files are specific for staging and production data storage and log file storage.

```
aws s3api put-bucket-lifecycle-configuration --bucket <bucket name> --lifecycle-configuration file://<file for bucket>.json 
```

You can check what rules are already applied to a bucket running

```
aws s3api get-bucket-lifecycle-configuration --bucket <bucket name>
```