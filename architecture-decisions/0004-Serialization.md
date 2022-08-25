
# 4. Allow the system to Serialize to multiple formats

Date: 2022-08-23

## Status

Decided

## Context

We are expecting to utilize work information to populate multiple systems.  For the moment we know that we will need information about Works described in PDC Describe to end up in both DataCite and PDC Discovery.

## Decisions

* Each `Work` object has a `metadata` field, stored in the database as JSON, which represents all of the metadata about this object.
* The `metadata` field will be read only.
* The `metadata` field contains the data necessary to drive the PDC Describe interface. We will need to store metadata about the interface that is not represented in DataCite.
* The `resource` is an in-memory representation of the `metadata` for a `Work`
* Changes to the `resource` are serialized to the `metadata` field by the `Work`
* We will make additional serialization formats external to the `Work`.
* All serializations, including DataCite,  will be stored in PDCSerialization module.
* All serializations, including DataCite, will accept a work and produce the correct output for their expected system.
* `metadata` is not tied to a specific serialization, but will contain enough data that it can be serialized to DataCite on demand.


## Consequences

* The `Work` `metadata` will be independent of external systems.
* The `metadata` can contain more information than any single external system requires.
* Many serializations can be added in the future without requiring a migration of our internal data structure.
