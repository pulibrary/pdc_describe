# 11. Recovery from a partial migration
Sometimes our automated migration of files from DataSpace fails, and the work is left in a partially migrated state. Here is how to recover from that.

1. Mark the line in the migration spreadsheet where the failure occurred and open a bug ticket for the failure. Figure out why it failed, and try to migrate that same data in the staging. 
2. Once it's fixed, deploy the new version of the software. 
3. Remove the partially migrated files from the pre-curation bucket using the aws web UI. BE VERY CAREFUL HERE.[1]
4. The work must be in `draft` state in order to migrate files. If you no longer have a `Migrate Dataspace Files` button you probably need to transition the work state. Open a rails console on the production server and do this:
   ```
   work = Work.find(WORK_ID); work.state = "draft"; work.save
   ```



[1] If you do accidentally delete more than you meant to, it is recoverable, but it will take sigificant staff time.