# 1. Embargo Process Upgrade
Date: 2025-04-18

## Status

Discussion

## Context

When content can not be immediately made public, but there is a desire for a DOI and or a public landing page for a Work, a curator will set an embargo date in the future before the work is approved.  Having an embargo date set will trigger the system to treat the files associated with the work as not public until after the embargo date has passed.

## Decision

* The system will store the files in an Embargo S3 bucket with a Globus endpoint separately from the rest of the post-curation content
* The curators have access to the embargo bucket via Globus. 
* The public has no access to the embargoed files.
* The depositor has no access to the embargoed files.

``` mermaid
sequenceDiagram
    actor dep as Depositor
    participant pdc as PDC Describe
    actor cur as Curator
    participant pre as Globus Pre Curation
    participant embargo as Globus Embargo
    participant post as Globus Post Curation

    dep->>pdc: deposit research
    pdc->>pre: store files
    dep->>cur: please embargo
    cur->>pdc: set embargo date
    dep->>pdc: grant license and release
    cur->>pdc: approve work
    pdc->>embargo: copy files
    pdc->>pre: delete files
    cur->>embargo: make any pre release updates
    pdc-->>pdc: check for embargoes ending yesterday at 12:05 am
    pdc->>post: embargo ended... copy files
    pdc->>embargo: delete files

```


## Consequences

* Embargoed files can not be accessed via any means by the public
* Curators can modify files while the work is under embargo
* The system automatically moves files out from embargo on the day after the embargo ends


## Notes
