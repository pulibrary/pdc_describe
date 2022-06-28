# ORCID ID import

We sometimes receive a payload of users' names, Princeton email addresses, net IDs, and ORCID IDs in the form of a spreadsheet.  While the application allows users' ORCID IDs to be stored individually, in an effort to integrate a large set of users from a manually-curated data source, we have written a rake task to optionally create/update users and their ORCID IDs from the command line.

## Retrieving the spreadsheet

The initial use case is for PPPL researchers.  A spreadsheet is separately maintained by the Research Data Developer (Chun Ly) at PPPL.

A shared copy of the spreadsheet with the net IDs added is [available here](https://docs.google.com/spreadsheets/d/1U6AuWCLogVGBcNXmH4p6o8ZQc2nleyt0s0TedOpNkC0/edit#gid=0).

PPPL staff maintain [a separate copy](https://docs.google.com/spreadsheets/d/1DYt7lpmy6RMqXXDNXvsIPWn0Aerw390ceBYfQl61um4/edit#gid=0) of this dataset with PPPL email addresses and no net IDs.  In general, PPPL researchers have both a PPPL email address and a Princeton net ID/email address.  These are separate accounts with separate authentication, and only the Princeton accounts are able to be used to authenticate via CAS.

### Loading into PDC Describe

1. Export the [spreadsheet](https://docs.google.com/spreadsheets/d/1U6AuWCLogVGBcNXmH4p6o8ZQc2nleyt0s0TedOpNkC0/edit#gid=0) to a CSV file and save to the server environment where the data needs to be loaded.
1. Run the following rake command:
  ```bash
  bundle exec rake orcid:populate\["orcid.csv"\]
  ```
  Rake task output will be sent to the Rails log.
1. You can inspect the data load by looking up users at the user path, example [http://localhost:3000/users/kl37](http://localhost:3000/users/kl37).  Users should now be created or updated and include correct ORCID IDs.

#### Reloading the data

Note that this rake task will reload the Princeton University email, net ID, and ORCID ID for users that already exist.  If the user does not exist or does not include full name/display name values, those will be pulled from the spreadsheet.  If users already exist in the database with those net IDs and also havevfull name/display name values already set, those name values will not change as part of the data import.


### Rebuilding the spreadsheet

In the event that the net ID copy of the spreadsheet needs to be rebuilt, proceed as follows:

1. Make a local copy of the https://github.com/pulibrary/search_netid repository.
1. Make a copy of the [PPPL sheet](https://docs.google.com/spreadsheets/d/1DYt7lpmy6RMqXXDNXvsIPWn0Aerw390ceBYfQl61um4/edit#gid=0).
1. To that new copy, add a column with the header **Net ID**.
1. Follow the [search_netid instructions](https://github.com/pulibrary/search_netid#instructions) with the first and last names from the spreadsheet in the `search_netid` manifest.  Copy the outputted values into the new copy of the spreadsheet, in the **Net ID** column.
