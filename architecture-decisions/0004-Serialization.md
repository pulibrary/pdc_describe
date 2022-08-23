

# 4. Allow the system to Serialize to multiple formats

Date: 2022-08-23

## Status

Discussion

## Context

We are expecting to utilize work information to populate multiple systems.  For the moment we know that we will ned information about Works described in PDC Describe to end up in both DataCite and PDC Discovery.

## Decisions

* Each `Work` object has a `metadata` field, stored in the database as JSON, which represents all of the metadata about this object.
* The `metadata` field will be read only.
* Each work will have a class representation of the metadata, `resource` for modification
* The `resource` will be serialized to the metadata automatically by the `Work` field prior to the object being store in the database.
* We will make additional serialization formats external to the `Work`.
* All serializations will be stored in PDCSerialization module.
* All serializations will accept a work and produce the correct output for their expected system.


## Consequences

* The `Work` `metadata` will be independent of external systems.
* The `metadata` can contain more information than any single external system requires.
* Many serializations can be added in the future without requiring a migration of our internal data structure.
