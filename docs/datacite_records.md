# Datacite Records

Each `Work` object has a `metadata` field, stored in the database as JSON, which represents all of the metadata about this object. This is a super-set of the metdata used by Datacite. For example, it contains information about author order, even though we don't yet have that in our Datacite records. 

ACTION: rename `data_cite` field to `metadata`
ACTION: Produce an ADR describing our internal serialization plan and why (we will store a JSON blob ("metadata") in the database and serialize to Datacite XML on demand)
ACTION: Remove the ".title" field from the work, replace it with a convenience method that fetches the title from the Resource
ACTION: Re-name PULDatacite module to PDCMetadata. Put classes each in their own file, and the module in a folder. 
ACTION: Move ValidDatacite class to a module PDCSerialization::Datacite

To map and serialize to Datacite XML, we use the [datacite-mapping](https://github.com/CDLUC3/datacite-mapping) gem published by the California Digital Library. 


### Current state
1. Data comes in via an HTML form
2. Those values are put into individual classes in PULResource
3. The PULResource is converted to JSON and stored in the database
4. When a work is edited, the JSON is read from the database and used the rehydrate the form via the fields in the PULResource class

### Desired state

```ruby
# Initial creation
work = Work.new
work.resource = PDCMetadata::Resource.new_from_form(params_from_form) # Only exists in memory
work.metadata = resource.to_json # This is stored in the database. This is an internal value, private method. 

# Editing
work = Work.find(id)
work.resource = PDCMetadata::Resource.new_from_metadata(work.metadata)
work.title => work.resource.titles(:main).value
work.resource.creators << PDCMetadata::Creator.new(...)
work.save => serializes JSON and saves it to database 

PDCMetadata::Resource
PDCMetadata::Creator
PDCMetadata::Identifier

PDCMetadata::Resource.new_from_json(work.metadata)

PDCSerialization::Datacite
PDCSerialization::DiscoverySolr


work.metadata => JSON that can rehydrate the form
work.to_xml => ValidDatacite.new_from_json(metadata).to_xml
```

#### Updating a record
```ruby
    work = FactoryBot.create(:shakespeare_and_company_work)
    resource = PULResource.new_from_json(work.metadata)

```


```mermaid
flowchart LR
    Work --> PDCMetadata::Resource
```

## Getting the DataCite record for a work via the application

For any work you can append `/datacite` to the url to get the DataCite XML serialization for that work:

```example
https://pdc-describe-prod.princeton.edu/describe/works/3/datacite
```

## Getting the DataCite record in the code

Note that we have FactoryBot definitions of some legacy datasets in `spec/factories/work.rb`


## Reference Material

1. [DataCite XML Reference](https://schema.datacite.org/meta/kernel-4/)
1. [datacite-mapping rubydocs](https://www.rubydoc.info/gems/datacite-mapping/0.4.1)
