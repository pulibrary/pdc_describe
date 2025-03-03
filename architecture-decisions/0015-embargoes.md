# 15. Transitioning Research Data Submissions from DataSpace to PDC - Describe

Date: 2023-11-28

## Status

Decided

## Context

When an object has files that are submitted but not intended to be available before a certain future date, those files are considered embargoed.  There are not many cases of objects with embargoed files in PDC.  We need a way to publish the object (that is, the object's DOI and its metadata) and indicate that there are files under an embargo that will be available at a later date that is also specified to the user, while not allowing the files to be accessed via the discovery interface.

## Decision

Curators will be able to add and edit an "Embargo date" field in the object's metadata, at the object level.  Embargoed files will move into the post curation bucket when an object is marked complete, but will not be made discoverable in the discovery interface (PDC Discovery).  In PDC Discovery, while an object's embargo date is in the future, the object's files will not be indexed by Solr, and a message will be displayed to the user on that object's page that the files are embargoed until a specified date.  When the embargo date has passed, or if the embargo is removed or edited to be in the past, the embargo message will no longer display, and the object's files will be available to the public via the discovery interface.  


## Consequences

1. While the path to do so would be convoluted, because the objects are in the post-curation bucket, they would be technically discoverable if someone had the full post-curation bucket file path.
2. Individual embargoes cannot be set per file; this will embargo all files associated with the object.  
3. Embargoes apply to files and file metadata, not to an object's descriptive metadata.  This technique does not allow an object's descriptive metadata to be embargoed.
