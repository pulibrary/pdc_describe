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

## Restoring the database
* [Download the latest database backup](https://console.cloud.google.com/storage/browser/pul-postgres-backup/13/daily/pdc_describe_prod?pageState=(%22StorageObjectListTable%22:(%22f%22:%22%255B%255D%22))&project=pul-gcdc&prefix=&forceOnObjectsSortingFiltering=false)
* Move or SCP the file to the rails local directory on your machine or the server 
* export the filename
  ```
  export BACKUP_FILE= <downloaded file name like: 13_daily_pdc_describe_prod_pdc_describe_prod_2023-08-24.Thursday.sql.bz2>
  ```
* Unzip the file
  ```
  bzip2 -d $BACKUP_FILE
  ```
* **Only needed if you are change the database name**
  * Development
    ```
    sed -i.bak 's/pdc_describe_prod/development_db/g' ${BACKUP_FILE%.*}
    sed -i.bak 's/production/development/g' ${BACKUP_FILE%.*}
    ```
  * Staging
    ```
    sed -i.bak 's/pdc_describe_prod/pdc_describe_staging/g' ${BACKUP_FILE%.*}
    sed -i.bak 's/production/staging/g' ${BACKUP_FILE%.*}
    ```
* remove any old data
  * Development 
    Stop your rails server first
    ```
    bundle exec rake db:drop db:create
    ```
  * Staging or Production
    * You must shut down nginx on both servers
      ```
      sudo service nginx stop
      ```
    * Then run a backup of the current database if desired
      ```
      echo $APP_DB_PASSWORD
      pg_dump -h $APP_DB_HOST -U $APP_DB_USERNAME $APP_DB > dump-before-restore.sql
      ```
    * Then remove the existing database
      ```
      bundle exec rake db:drop db:create DISABLE_DATABASE_ENVIRONMENT_CHECK=1
      ```
* Restore the file ([see postgres documentation for more information](https://www.postgresql.org/docs/8.1/backup.html))
  * Development
    * Find the Port lando is running on 
      ```
      lando info |grep external_connection
      ```
    * run psql with that port
      ```
      psql -h "127.0.0.1" -p <port from above> -U postgres -f ${BACKUP_FILE%.*} development_db
      ```
  * Staging or Production
    ```
    echo $APP_DB_PASSWORD
    psql -h $APP_DB_HOST -U $APP_DB_USERNAME -f ${BACKUP_FILE%.*} $APP_DB
    ```
* Test the system
  * Note if you are logged in you may show up as another user.  You should logout and log back in if you are the wrong user
    * We could possibly `update_attribute(:session_token, SecureRandom.hex)` for all users if security is a concern
