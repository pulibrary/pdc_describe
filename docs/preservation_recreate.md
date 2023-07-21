# Preservation

PDC Describe's preservation strategy for MVP release should allow for the following:

* A full application restore from the last system backup.
* An individual object reassembly from backups using the DOI to locate files and metadata in cloud storage.

## Files and directories

* Object files are stored in Amazon S3 under a directory structure based on their DOIs.
* Objects can be retrieved from S3 using the DOI to determine location.
* DataCite XML, object metadata from Rails as JSON, and provenance metadata as JSON are exported to a sidecar directory called `princeton_data_commons` within the DOI directory for the object in S3.

### Note on `princeton_data_commons`

This directory and these files are created in the application when the object is approved and completed.  To test this functionality or to recreate these files for a specific work, a rake task is also available, example syntax below:

```bash
$ bundle exec rake works:preserve["424","pdc-describe-staging-postcuration","10.80021/1tzs-ph44/424"]
```

### Example Backup Directory Structure:

For example, assuming that this is the DOI for the object that needs to be recreated, `10.80021/1tzs-ph44`:

```
- s3:/bucket/10.80021/1tzs-ph44/42/
  * file1.png
  * dataset.zip
  * princeton_data_commons/
    * datacite.xml
    * metadata.json
    * provenance.json
```

## Recreating an object from S3

1. Locate the DOI folders in the appropriate bucket is S3.
1. Download all of the files within the folder associated with the object, including the contents of the `princeton_data_commons` folder, which should contain three files as noted in the example directory structure aboveabove.
1. Repopulate the metadata field values in the PDC Describe interface using the contents of `metadata.json`.  This file contains non-markdown formatting information such as line breaks that do not belong in the `datacite.xml` file.
   * Notice that this process can be quite involved *if* the `metadata.json` file was created with a version of PDC Describe that does not have the same structure as the current version of the metadata. For example if the `metadata.json` was created without mandatory fields that have been added recently the process to recreate the object in PDC Describe from the metadata file will need to account for this somehow.
1. Upload all of the object's files downloaded to PDC Describe and complete the ingest process.  This will mint a new DOI.
1. Rename the `provenance.json` file that you downloaded from the backup to `provenance_$DATE.json` where `$DATE` equals the date of the recreation being performed, and upload this to the new object's `princeton_data_commons` folder, to preserve previous provenance activity.

### Future improvements

* Allow admin users performing an object recreation to specify the old DOI when recreating the object (note that this will re-use the existing DOI directory structure in S3 for the object that is being recreated).
* Sync post-curation S3 buckets to another backup location so that backups can be restored from a second copy, not from post-curation.
