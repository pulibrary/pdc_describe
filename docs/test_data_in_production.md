# How to move data from test fixtures to production

One of our goals for data migration is to have 5 - 10 sample objects for which we have:
* Validated description in our submission form
* Solid, well tested indexing and display in PDC Discovery

In order to deliver this, we will:
* Describe representative test records using rspec system specs (see, e.g., `spec/system/bitklavier_form_submission_spec.rb`)
* Validate the DataCite records that are produced by that system spec with our data curators
* Move the metadata produced by that system spec into our staging system
* That will give us a known and consistent target to work with as we zero in on how to index these works for PDC Discovery.

## Process

### 1. Create a system spec
Work with RDOS to ensure we're identifying representative samples. We want to cover a range of use cases (e.g., works that have a DOI already, works that have a DOI from PPPL, works that do not have DOI yet and will mint one upon migration).

### 2. Update system specs as needed
These will need to be kept updated with changes to the UI, changes to the metadata schema, etc.

### 3. Create or refresh the work in staging
  1. Regenerate the json representations of the migration data by running:
     ```
     DATA_MIGRATION=true bundle exec rspec spec/system/data_migration
     ```

  2. Copy the newly created .json files to the server where you want to load them: 
    ```
    scp tmp/data_migration/*.json deploy@pdc-describe-staging1.princeton.edu:/tmp
    ```

3. Then, ssh to the server where you want to create this sample work as the `deploy` user. 
4. Run the import rake task, specifying the location of the .json files and the netid of the user they should import as:
  ```
  bundle exec rake works:import_works\[/path/to/json/files,bs3097]
  ```
  Note the backslash before the square brackets, and no space after the comma. 

  The work should now be visible in the application.
3. The works will be in a draft state. If you are testing the migration process, at this point you should attach the payload files and mark the record "ready for review." Then our QA checkers in RDOS and PPPL should be able to review them.

## Reloading a Single work

The process for reloading a single work is similar to the process for loading all the data.  The large difference is you need to remove the offending work prior to reloading the work.

1. Update the test to produce the corrected json

1. Run the test with `DATA_MIGRATION=true` to generate a new json file

   ```
   DATA_MIGRATION=true bundle exec rspec spec/system/data_migration/<updated test>
   ```

1. scp the file to the server `<server>` like `pdc-describe-staging1.princeton.edu`

   ```
   scp tmp/data_migration/<output file>.json deploy@<system>:/tmp
   ```

1. The reset of the instructions are on the server, so SSH on to it

   ```
   ssh deploy@<system>
   ```

1. Move the file to it's own directory

   ```
   mkdir /tmp/<new-dir>
   mv /tmp/<output file>.json /tmp/<new-dir>
   ```

1. Destroy the offending work.  This assumes you have the `<id>` of the work in the system

   ```
   cd /opt/pdc_describe/current
   bundle exec rails c
     work = Work.find(<id>)
     work.destroy
   end
   ```

1. Reload the offending work

   ```
   bundle exec rake works:import_works\[/tmp/<new-dir>,<your uid>]
   ```