# Revoking a Work
Revoking a work can happen either prior to publishing or after a work has been approved and published.  The procedure for revoking a work depends on if the work has been published and if the DOI has been released by the depositor.

## Approved/Published Works
If a work has been approved and published we will endeavor to encapsulate these manual commands into a button in the interface, but for the moment the manual workflow is being stated here.  Choose your workflow based on the end state of the work you are trying to revoke.

### Embargo
When a work has been published, but now needs to be embargoed.

1. Move the data from post-curation to embargo in [aws](princeton.edu/aws)
   1. In the [post-curation bucket](https://us-east-1.console.aws.amazon.com/s3/buckets/pdc-describe-prod-postcuration?region=us-east-1&tab=objects) find the doi and move it to pre-curation
1. Set the Embargo Date by editing the work in PDC Describe
   1. The embargo date can be found under the curator controlled metadata
1. Run the Index on the PDC Discovery server
   1. ssh onto the discovery server
      ```
      ssh deploy@pdc-discovery-prod1.princeton.edu
      ```
   1. Making note of the work id and changing it in the url, run index on the work
      ```
      cd /opt/pdc_discovery/current
      bundle exec rake index:single_index[https://datacommons.princeton.edu/describe/works/<work-id>.json]
      ```

### Draft
When a work has been approved inadvertently and now needs to be sent back to the user in draft state.

1. Move the data from post-curation to pre-curation in [aws](princeton.edu/aws)
   1. In the [post-curation bucket](https://us-east-1.console.aws.amazon.com/s3/buckets/pdc-describe-prod-postcuration?region=us-east-1&tab=objects) find the doi and move it to pre-curation
1. Delete the data from the preservation bucket
   1. In the [preservation bucket](https://us-west-1.console.aws.amazon.com/s3/buckets/pdc-describe-prod-preservation?region=us-west-1&tab=objects) fid the doi and delete the data.  Make sure only there is only one work id in the doi bucket.  If not only delete your work id directory
1. Set the state to Draft
   ```
   id = <id to withdraw>
   uid = <your uid>
   user = User.find_by(uid:)
   work = Work.find(id)
   work.draft!(user)
   ```
1. Change the DOI from Findable to Registered
   1. **Note** we do not currently have the correct credentials to do this step
1. Run the Index on the PDC Discovery server
   1. ssh onto the discovery server
      ```
      ssh deploy@pdc-discovery-prod1.princeton.edu
      ```
   1. Making note of the work id and changing it in the url, run index on the work
      ```
      cd /opt/pdc_discovery/current
      bundle exec rake index:single_index[https://datacommons.princeton.edu/describe/works/<work-id>.json]
      ```

### Withdrawn
When the work needs to be retracted.

1. Delete the data from [post-curation bucket](https://us-east-1.console.aws.amazon.com/s3/buckets/pdc-describe-prod-postcuration?region=us-east-1&tab=objects).  
1. The data will stay in preservation for 1 year. Mark your calendar to delete the data a year from now
1. Add a provenance note about the reason for the withdraw
1. Change the DOI from Findable to Registered
   1. **Note** we do not currently have the correct credentials to do this step
1. Set the state to Withdrawn
   1. ssh onto the describe server
      ```
      ssh deploy@pdc-describe-prod1.princeton.edu
      ```
   1. Within the rails console withdraw the work
      ```
      id = <id to withdraw>
      uid = <your uid>
      user = User.find_by(uid:)
      work = Work.find(id)
      work.withdraw!(user)
      ```

1. Run the Index on the PDC Discovery server
   1. ssh onto the discovery server
      ```
      ssh deploy@pdc-discovery-prod1.princeton.edu
      ```
   1. Making note of the work id and changing it in the url, run index on the work
      ```
      cd /opt/pdc_discovery/current
      bundle exec rake index:single_index[https://datacommons.princeton.edu/describe/works/<work-id>.json]
      ```

## Draft Works
When a work has not yet been approved/published and the work remains in the draft or awaiting approval states, the withdraw is less time sensitive.  We assume that these steps will remain manual into the future
The consideration for which set of steps to run through is based on who is triggering the withdraw and if the DOI has been utilized.  If the depositor triggers the withdraw and confirms the the DOI is unused the draft can be put in the deletion_marker state.  If we do not have confirmation that the DOI is unused, or know that it has been published the draft will need to end up in a withdrawn state.  When in doubt choose to put the work in the withdrawn state.

### Withdrawn
When the DOI has been published, or may have been published, but the work was never completed and approved.

1. If any data is present in [aws](princeton.edu/aws)
   1. Move the data from [pre-curation](https://us-east-1.console.aws.amazon.com/s3/buckets/pdc-describe-prod-precuration?region=us-east-1&tab=objects) to [preservation bucket](https://us-west-1.console.aws.amazon.com/s3/buckets/pdc-describe-prod-preservation?region=us-west-1&tab=objects).  
   1. The data will stay in preservation for 1 year. Mark your calendar to delete the data a year from now
1. Add a provenance note about the reason for the withdraw
1. Set the state to Withdrawn
   1. ssh onto the describe server
      ```
      ssh deploy@pdc-describe-prod1.princeton.edu
      ```
   1. Within the rails console withdraw the work
      ```
      id = <id to withdraw>
      uid = <your uid>
      user = User.find_by(uid:)
      work = Work.find(id)
      work.withdraw!(user)
      ```
      **Note** If the work does not have minimum metadata and the withdraw errors, You will need to run the following:
      ```
      work.state = "withdrawn"
      work.save!(validate:false)
      work.send(:track_state_change,user,"withdrawn")
      ```
1. Run the Index on the PDC Discovery server
   1. ssh onto the discovery server
      ```
      ssh deploy@pdc-discovery-prod1.princeton.edu
      ```
   1. Making note of the work id and changing it in the url, run index on the work
      ```
      cd /opt/pdc_discovery/current
      bundle exec rake index:single_index[https://datacommons.princeton.edu/describe/works/<work-id>.json]
      ```

### Deletion Marker
When the depositor has requested the draft be removed.

1. Delete the data from [pre-curation](https://us-east-1.console.aws.amazon.com/s3/buckets/pdc-describe-prod-precuration?region=us-east-1&tab=objects)  
1. Add a provenance note about the reason for the deletion
1. Set the state to deletion_marker
   1. ssh onto the describe server
      ```
      ssh deploy@pdc-describe-prod1.princeton.edu
      ```
   1. Within the rails console remove the work
      ```
      id = <id to remove>
      uid = <your uid>
      user = User.find_by(uid:)
      work = Work.find(id)
      work.withdraw!(user)
      work.remove!(user)
      ```
      **Note** If the work does not have minimum metadata and the remove errors, You will need to run the following:
      ```
      work.state = "deletion_marker"
      work.save!(validate:false)
      work.send(:track_state_change,user,"deletion_marker")
      ```
1. Change the DOI from Registered to Draft
   1. **Note** we do not currently have the correct credentials to do this step
