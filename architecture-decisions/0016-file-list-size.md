# 1. Indexing of File List
Date: 2025-03-17

## Status

Approved

## Context

When we store data for a dataset in PostgreSQL we store the dataset metadata and also the entire list of files associated with the dataset. Some datasets have a small number of files while others contain thousands of files. 

## Decision

* We are currently storing the entire file list in a `json` field in PostgreSQL.
* A single `jsonb` field was easiest way to store the data into PostgreSQL. 
* A single `jsonb` field makes it easy also to read the data and display the file list to the users.


## Consequences

* A problem with storing the file list into a single list is that eventually the file list will be too big to be stored as a single file list.
* When we receive a dataset with a file list too large we won't be able to handle it without making modifications to the system.
* At this point we do not know how large this file list will need to be before it breaks the system but we know the approach will not be scalable forever.
* As of today, our largest dataset, the [CLEVR-Matrices](https://datacommons.princeton.edu/describe/works/470) has 60,005 files and the system is handling it well.


## Notes
In addition to the storage issue describe here, at some point we will also need to consider how to *fetch and display* the entire file list to the user. We currently fetch the entire list at once via AJAX but this approach will not scale if the file list where to have millions of files. 

Other approaches are available to handle the display of large lists (e.g. pagination) and this is something that would need to be addressed when we decide to support extremely large file lists.

This ADR is related to the [Indexing of File List](https://github.com/pulibrary/pdc_discovery/blob/main/architectture-decisions/0001-indexing-file-list.md) in PDC Discovery.