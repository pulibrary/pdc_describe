# 12. Document process and tooling for backing up collections in DataSpace

Date: 2023-08-23

## Status

Decided

## Context

We need to back up and preserve all data and files from all items in Research Data collections, as they are migrated from DataSpace to PDC Describe, collection-by-collection.  The backups should be stored securely in the cloud and able to be made available for staff to locate a collection or object's preserved data easily from the ARK that was created in DataSpace.

## Decision

1. We will migrate the data from DataSpace to PDC Describe using workflows borrowing from [this ADR](https://github.com/pulibrary/pdc_describe/blob/main/architecture-decisions/0005-legacy-data-migration.md).
2. Once a collection is indicated as completely migrated in [this spreadsheet](https://docs.google.com/spreadsheets/d/148EHw1FuYhd4kqov5UA04cpSekMGGlAy3zakBwuowFo/edit#gid=0), it is ready to be preserved.
3. Using the code and following instructions in the README from the [`dataspace_preservation`](https://github.com/pulibrary/dataspace_preservation) repository, back up the collection from DataSpace.  This process will create a compressed archive of AIPs of each object in a manifest of ark identifiers generated as part of the process outlined in its instructions.
4. Name the compressed archive after the ark of the collection it is preserving, using "+" and "=" for ":" and "/" to make individual archives' filenames saveable.  For example, the collection with the handle `ark:/88435/dsp010g354h44r` would be backed up as `ark+=88435=dsp010g354h44r.tgz`.
5. Store the backed up collection in the S3 DataSpace preservation bucket `preserve-dataspace`.

## Consequences

Preservation of DataSpace collections will be a manual process that must be initiated and undertaken by an individual, by hand.  Collections can be frozen in DataSpace (that is, submission permissions suspended for all users) at any time.  The `dataspace_preservation` tool creates AIP files from a list of arks provided to it, and could be used to generate separate AIP files if needed, or regenerate collection backups, however collection backup should be coordinated with those performing the migration, and happen after the collection's submission workflow has been frozen.
