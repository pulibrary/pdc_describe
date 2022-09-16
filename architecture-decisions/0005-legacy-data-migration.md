
# 5. Migration of Legacy Data

Date: 2022-09-15

## Status

Decided

## Context

We have approximately 340 data sets that need to be migrated from DataSpace to the Princeton Data Commons suite of applications. In this context, a work has been migrated when:
1. The record has been redescribed in PDC Describe
2. The data payload has been moved to the new post-curation bucket and is available for download via the PDC Production Globus instance
3. Any URL redirection (e.g., DOIs, ARKs) has been updated to point to the new location
4. The old content has been removed

## Decisions
1. We will use PDC Discovery as the datasource of record for which items have been migrated. 
   1. When a work is migrated, we will add a field to the PDC Discovery index that flags it as migrated from DataSpace.
   2. Once a record is migrated, only the migrated record should appear in a Discovery search (suppress the other one).
   3. We need to be able to query against the `migrated` flag in Discovery, and that will allow us to track progress for how many of the records have been migrated at any given time.
2. We want to update the DOIs at migration time. We can redirect DOIs in the `10.34770` namespace (general Princeton research data). 
3. Existing PPL DOIs are minted by OSTI.  We cannot redirect these using the above method, as we do not own them.  However, the OSTI DOIs do not seem to be DataCite DOIs.  For example, the `10.11578/1367870` OSTI DOI (referenced at [https://www.osti.gov/dataexplorer/biblio/dataset/1367870](https://www.osti.gov/dataexplorer/biblio/dataset/1367870)) does not resolve under the `doi.datacite.org` domain.  As evidenced by examining the DOI metadata, the `site_url` value set by OSTI which powers their redirect to DataSpace is set to the Princeton handle server and the EZID ark that we control (example: [http://arks.princeton.edu/ark:/88435/dsp01dj52w7187](http://arks.princeton.edu/ark:/88435/dsp01dj52w7187)).  We can change the ark URL redirect by updating the "Location (URL)" field value in EZID (example: [https://ezid.cdlib.org/id/ark:/88435/dsp01dj52w7187](https://ezid.cdlib.org/id/ark:/88435/dsp01dj52w7187)).  We can do this in batches or one at a time using the EZID API.
4. The overall migration process will look like this: 
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

