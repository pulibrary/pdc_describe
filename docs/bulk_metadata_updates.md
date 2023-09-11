# Bulk Metadata Updates
When we have metadata updates that need to be undertaken thoughout the system, this is the process.

## PPPL Department Name Change
PPPL department names appear in the `subcommunities` field in PDC Describe, because that is how they were labeled in the legacy DataSpace application.
1. Update the UI and tests to reflect the new change
2. Update the change map in `WorkUpdateMetadataService`
3. Test the change locally, and follow regular software release processes
4. Once the updated code is on the server, run the rake task to update any existing records to the new PPPL department name:
   ```
   bundle exec rake metadata:update_pppl_subcommunities\[YOUR_NETID] 
   ```