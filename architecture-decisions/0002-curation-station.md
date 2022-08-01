# 2. Data Storage and the Curation Station

Date: 2022-07-25

## Status

Accepted

## Context

Data Curators need a workstation where they have easy access to curation specific software applications and all of the research data under curation. In addition, we need storage locations for pre-curated and post-curated data. 

## Decisions

* We will use two Amazon S3 buckets: one for pre-curated and one for post-curated data. 
* There will be two Globus end points configured, one for each of the pre-curation and post-curation S3 buckets. 
* The curation station will be a high powered physical Windows machine that will be housed in the data center. Data curators will use a remote desktop client to interact with it.
* Both S3 buckets will be mounted on the curation station. 
* There will be a Globus client on the curation station which can be used to sync files with the S3 buckets on an as-needed basis. This may also be automated in some way, but any automation is left to the discretion of the data curators.
* PDC Describe will put any file attachments into the pre-curation S3 bucket, in a folder named by the DOI of the work
* End users will be able to upload via Globus endpoint to the pre-curation S3 bucket
* Only PRDS staff members (or automated processes kicked off by PRDS staff members) will be able to write to the post-curation S3 bucket. 
* The post-curation S3 bucket will be the data source for the Princeton Data Commons Globus endpoint. It will be organized by DOI. All data in it will be publicly accessible.

## Consequences

* Neither the software development team nor the operations team can take responsibility for the configuration of Globus on the curation station. This decision puts that responsibility in the hands of the curators, who are both our most knowledgable staff members with regard to Globus, and also the people who will be using it the most and can best judge what will be most useful and adjust it themselves.
* Globus is increasingly recognized as an important service in the PUL portfolio, and as such we are treating it as a first class production service. That means its setup should be automated and documented as much as possible (see https://github.com/pulibrary/rdss-handbook/blob/main/globus.md)
* Access keys to S3 will be managed by AWS service accounts under the control of the operations group. 
