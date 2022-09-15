
# 6. Migration of Legacy Data

Date: 2022-09-15

## Status

In Development

## Context



## Decisions
1. We will use PDC Discovery as the datasource of record for which items have been migrated. 
   1. When a work is migrated, we will add a field to the PDC Discovery index that flags it as migrated from DataSpace.
   2. Once a record is migrated, only the migrated record should appear in a Discovery search (suppress the other one).
   3. We need to be able to query against the `migrated` flag in Discovery, and that will allow us to track progress for how many of the records have been migrated at any given time.
2. We want to update the DOIs at migration time. We can redirect DOIs in the `10.34770` namespace (general Princeton research data), but so far we cannot redirect DOIs in the PPPL namespace. One important question is whether we can develop a timely workflow to use for this, or whether we will need some temporary solution such as a load balancer redirect for traffic going to legacy PPPL DOIs. 
   1. We will therefore start the migration with non-PPPL content, in order to give lead time for researching the question of how to redirect the PPPL DOIs. 
3. The overall migration process will look like this: 
    1. Describe the record in pdc_describe
    2. Submit the data payload via pdc_describe
      a) via the form for objects < 100Mb
      b) upload directly via Globus or S3 for big data
    3. A curator checks the DataCite record that we produce and refines as necessary
    4. Upon approval:
       1. the data payload is moved to the new S3 bucket automatically (the same way it would be for a non-legacy submission)
       2. the migrated object is indexed from PDC Describe into PDC Discovery
       3. the DOI is updated via the DataCite.org API to point to PDC Discovery (Note that this might be a manual process for PPPL content.)
    5. Verify that the DOIs has been redirected to point to PDC Discovery (How long does a redirect directive to DataCite.org take?)
    6. A human being will then delete the data payload from from the legacy location and remove the record from DataSpace



## Consequences
1. Migrating PPPL DOIs might be better undertaken as a batch. We would need PDC Discovery to be able to use a DOI in the URL for an object. If we had that, we could ask OSTI to update all of their DOI pointers anytime. 

https://dataspace.princeton.edu/bitstream/88435/dsp018623j1954/1/SourceData.xlsx