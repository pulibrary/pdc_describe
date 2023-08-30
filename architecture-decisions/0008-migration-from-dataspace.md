# 8. Migration procedures from DataSpace

Date: 2023-?-?

## Status

Discussion

## Context

We have approximately 370 research data sets in a legacy DSpace application, branded locally as DataSpace. We need to migrate research data objects out of DataSpace and into PDC Describe. There are some challenges inherent in this:

1. Objects in DataSpace are described inconsistently
2. We do not have identifiers for many of the authors and funders
3. We do not have DOIs for many of the objects
4. We do not have README files for many of the objects
5. The objects have not been curated according to our current data curation standards
6. The actual data for the objects can be either in DataSpace or in a Globus instance, or sometimes in both places. 

This document incorporates [migration requirements from PPPL](https://docs.google.com/document/d/1MgjwkeSZZaSJd6jnWGlJdGoX-2vmmDgOM4xD-CH37Cw/edit#heading=h.utxq5j20ujv1).

## Decisions

Our migration process will be as follows:

### Tracking of migration process
1. Tracking will happen in the [DataSpace Collections Migration Tracking Spreadsheet](https://docs.google.com/spreadsheets/d/148EHw1FuYhd4kqov5UA04cpSekMGGlAy3zakBwuowFo/edit#gid=0)
1. Tracking on a per-collection basis will happen in the first tab, labeled "Collections"
   1. Migrate PPPL collections first
2. Tracking on a per-item basis will happen on [the second tab](https://docs.google.com/spreadsheets/d/148EHw1FuYhd4kqov5UA04cpSekMGGlAy3zakBwuowFo/edit#gid=684248489) of the same spreadhsheet
3. When the migration is complete, we will archive any spreadsheets used during the migration in this code repo, in case they are needed for future reference.

### Migration of an individual item
1. Check in with the migration team and agree on which collection is currently being migrated. Ensure the `Migration in progress` column is set to `Yes` for the collection in progress.
2. Indicate on the [individual item tracking sheet](https://docs.google.com/spreadsheets/d/148EHw1FuYhd4kqov5UA04cpSekMGGlAy3zakBwuowFo/edit#gid=684248489) that you are taking a particular item, so we don't get two people trying to migrate the same item. Put your netid in the `migrator` column of the spreadsheet. You can also make that row in the spreadsheet a different color. 
3. Authenticate into PDC Describe and click the button with your Name or NetID on it in the top right corner. This will reveal "Migrate PPPL Dataset" and/or "Migrate PRDS Dataset" menu items.
     * Migration *must* happen via these menu items instead of via the wizard used for new deposits. Using these menu items is the only way to reach an interface that will let you enter an existing DOI (instead of minting a new one) and is the only way to record that a dataset is the result of a migration.
4.  Re-describe the data set, referring to the metadata in DataSpace (get the url for an item from the spreadsheet). Note that your job is to *re-describe* the item. The metadata in DataSpace is often incomplete and sometimes wrong. Use your best judgement as a data curator. 

### Checklist of migration tasks:

## Required Metadata

#### Title
Enter the title as it is in DataSpace

#### Description
1. All variations on description are going into the same field. We are not going to distinguish between `abstract` and `description`, or other kinds of descriptive text.
2. Remove all references to `Globus` from the description field. These will not be necessary in the new system, and they are not actually a description of this dataset. 

#### Rights
Use the default value, "Creative Commons Attribution 4.0 International"

#### Creators
1. Enter the creators of the work in publication order. Author order matters. 
2. Enter an ORCID identifier for every creator you can find. There is [a spreadsheet of ORCIDs for PPPL](https://docs.google.com/spreadsheets/d/1U6AuWCLogVGBcNXmH4p6o8ZQc2nleyt0s0TedOpNkC0/edit#gid=0) researchers. If the ORCID is not on the spreadsheet, do not try to track it down. 
3. Be sure the name is recorded as it is on the DataSpace record. Do not update it to match the official name in ORCID. 

## Additional Metadata

#### Keywords
If they exist in the DataSpace record, copy them here.

#### Funding Reference
1. Where possible, identify the funders of the work that created this dataset, along with the Award Number and Award URI if known.
2. In DataSpace, funders are often found listed as a `Contributor`. Sometimes they can also be found in the README file if that exists. 
3. Where possible, record the Research Organization Registry (ROR) identifier for an organization. Consult [https://ror.org/](https://ror.org/).
4. Every PPPL item should include ROR https://ror.org/01bj3aw27 (US Department of Energy), with award number DE-AC02-09CH11466

#### Related Objects
If there is a related object referenced in the DataSpace record, enter it here.

#### Additional Individual Contributors
Enter any other individual contributors as they exist on the DataSpace record.

#### Additional Organizational Contributors
Enter any other organizational contributors as they exist on the DataSpace record.

#### Domains
All PPPL works should go under "Natural Sciences". For other works, look at what DataSpace collection the work is coming from and consult [this mapping](https://github.com/pulibrary/pdc_discovery/blob/8c0482bc35006fd1d74a1cac34c2039d1eb7f0db/lib/traject/domain.rb#L23-L47) to determine which domain it belongs in.

#### Communities
If there are any communities recorded on the DataSpace record, enter them here.

#### Subcommunities
These are particularly important for PPPL. Note that there can be more than one for a record, because in DataSpace these values are nested. In the screenshot below, for example, both "Advanced Projects" and "Stellerators" should be recorded.
<img src="images/nested_pppl_collections.png"
     alt="Screenshot of nested PPPL collections"
     style="margin-left: 10px; height: 100px" />

To select more than one option from the subcommunities form, hold down your command button and click on the options you want.
<img src="images/multiselect.png"
     alt="Screenshot of subcommunities form element with multiple options selected"
     style="margin-left: 10px; height: 100px" />



## Curator Controlled

#### Publisher
For PPPL items, the publisher should be "Princeton Plasma Physics Laboratory, Princeton University." For all other items, the publisher should be "Princeton University"

#### Publication Year
Record the publication year as recorded in DataSpace

#### DOIs

If a work already has a DOI, it is important that we NOT register a new one. 

1. If there is an existing DOI, enter it here. If this work is from PPPL, it likely has an existing DOI that is not in DataSpace. These should be pre-populated in the migration spreadsheet.
2. Not every items in DataSpace will have a DOI. If you do not enter an existing DOI, the system will mint a new one.  

#### ARK
The ARK is the unique identifier from DataSpace that will allow us to migrate the data payload. Make sure to enter the ARK exactly how it appears in DataSpace. 

#### Resource Type 
This will almost always be DataSet.

#### Group
2. Works from PPPL should go into the `Princeton Plasma Physics Lab` group. For PPPL items, also record the subcollections. Note that many PPPL items might belong to more than one subcollection.
3. Everything else goes into the PRDS group.

#### Click Migrate
When you are done re-describing the work, click the "Migrate" button at the bottom of the screen.
  
#### Migrate the data
1. Once your metadata is complete, you can click the "Migrate Dataspace Files" button on the work show page and the data from this work will be automatically moved from DataSpace to PDC Describe pre-curation. In some cases this might take a long time. You may need to put the work down for a day and come back to it after the migration process is complete.  
   1. **Note:  The migration of data is queued in the background, so your browser will return after all files are queued, but before the file data has completed migration.**
   2. If the migration fails, open an issue in the [PDC Describe issue queue](https://github.com/pulibrary/pdc_describe/issues). Make sure to include your name, the ARK of the item you're trying to migrate, and the approximate time of the error (so we can find it in the error logs and get more details). 
   3. Some objects will not be able to migrate automatically. If this object is one of those, we will follow the procedures documented in the [Manual Data Migration ADR](0010-manual-data-migration.md). 

#### Ask someone to check your work
1. We want at least two people from the migration team to check every item. One person should re-describe the item, and another person should check it in PDC Describe, and approve it once it is ready. If there needs to be discussion about the correct description, use the PDC Describe interface so we can exercise that interface functionality, and also so we will have a record of the discussion and the decision that was reached. 
2. When the item has been checked and approved, the data will be automatically moved to PDC's post-curation data store, and the metadata will be indexed in PDC Discovery. Check that it is appearing as expected, and that the data can be downloaded as expected.

#### Mark the item complete on the migration spreadsheet
1. When the migration of a work is finished, put its PDC Describe id into the tracking spreadsheet, and turn that row in the spreadsheet green.
2. When all of the works for a particular collection are finished, indicate this in the collection tracking spreadsheet. 

### When a collection is done
1. Mark the collection done in the spreadsheet
2. Update the DataSpace collection ARK like this:
   ```
   EZID_USER=xxxxx EZID_PASSWORD=xxxxx be rake dspace:update_ark\["ark:/88435/dsp01k643b3527","https://datacommons.princeton.edu/discovery/\?f%5Bcommunities_ssim%5D%5B%5D\=Princeton+Plasma+Physics+Laboratory\&f%5Bsubcommunities_ssim%5D%5B%5D\=Advanced+Projects"]
   ```
3. Check that the collection ark has been redirected by visiting http://arks.princeton.edu/ark:/YOUR/ARK, e.g., http://arks.princeton.edu/ark:/88435/dsp01k643b3527
4. Mark the collection ark as updated on the migration spreadsheet

## After the migration
1. We will take a second pass to ensure that there were no new works added to DataSpace after we started the migration
2. We will archive the spreadsheets used in the migration process
3. We will backup and then disable the collections that have been migrated, and direct all new deposits for a migrated collection to use PDC Describe

## Consequences
We are making every effort to comply with Core Trust Seal best practices during this data migration. We are recording the identity of the person who is redescribing the work, and the identity, timestamp, and checksum values for the data that is migrated. 