# pdc_describe

Cataloging application for PDC content and more

[![CircleCI](https://circleci.com/gh/pulibrary/pdc_describe/tree/main.svg?style=svg)](https://circleci.com/gh/pulibrary/pdc_describe/tree/main)

[![Coverage Status](https://coveralls.io/repos/github/pulibrary/pdc_describe/badge.svg?branch=main)](https://coveralls.io/github/pulibrary/pdc_describe?branch=main)

## Dependencies
See `.tool_versions`

## Local development

### Setup
1. Check out code and `cd`
1. Install tool dependencies
    1. [Lando](https://docs.lando.dev/getting-started/installation.html)
    1. [asdf](https://asdf-vm.com/guide/getting-started.html#_2-download-asdf)
1. Install asdf dependencies
    1. `asdf plugin add ruby`
    1. `asdf plugin add nodejs`
    1. `asdf plugin add yarn`
    1. `asdf plugin add awscli`
    1. `asdf install`
    1. ... but because asdf is not a dependency manager, if there are errors, you may need to install other dependencies. For example: `brew install gpg` or `brew install pkgconfig`
1. Install language-specific dependencies
    1. `bundle install`
    1. `yarn install`
1. Set up local AWS credentials
   1. Put a stanza like this in your UNIX setup environment (e.g., `.zshrc` or `.bashrc`). Get the AWS secrets from the staging server:
   ```
   # AWS settings for PDC Describe
   # (copied these values from ENV staging)
   export AWS_S3_POST_CURATE_BUCKET="pdc-describe-staging-postcuration"
   export AWS_S3_PRE_CURATE_BUCKET="pdc-describe-staging-precuration"
   export AWS_S3_SECRET_KEY="AWS_S3_SECRET_KEY"
   export AWS_S3_POST_CURATE_REGION="us-east-1"
   export AWS_S3_PRE_CURATE_REGION="us-east-1"
   export AWS_S3_KEY_ID="AWS_S3_KEY_ID"
   ```

#### Troubleshooting sqlite
If you are having trouble installing sqlite3 on an M-series mac, try making a file called `.bundle/config` and put this into it (this assumes you're using homebrew) [Source](https://github.com/sparklemotion/sqlite3-ruby/blob/main/INSTALLATION.md): 

```
---
BUNDLE_BUILD__SQLITE3: "--enable-system-libraries --with-sqlite3-include=/opt/homebrew/opt/sqlite/include --with-sqlite3-lib=/opt/homebrew/opt/sqlite/lib --with-sqlite-cflags='-DSQLITE_DEFAULT_CACHE_SIZE=9999 -DSQLITE_DEFAULT_PAGE_SIZE=4444'"
```

### Starting / stopping services
We use lando to run services required for both test and development environments.

Start and initialize database services with:

`bundle exec rake servers:start`

To stop database services:

`bundle exec rake servers:stop` or `lando stop`

### Running tests
1. Fast: `bundle exec rspec spec`
2. Run in browser: `RUN_IN_BROWSER=true bundle exec rspec spec`

### Starting the development server
1. `bundle exec rails s -p 3000`
2. Access application at [http://localhost:3000/](http://localhost:3000/)

### Give yourself admin privs in your local dev instance
1. Login at [http://localhost:3000/](http://localhost:3000/) so a `User` exists.
2. Enter the rails console: `bundle exec rails console`
3. Elevate your privs: `User.new_super_admin("your NetID here")`

Separate from admin, users may also be [given permission](docs/how_to_add_postdated_provenance.md) to add post-dated notes in the provenance / change log.

### Development with AWS resources
Tests should never depend on outside resources, and it's best minimize dependencies during development, too, but it can be useful. To give your local instance access to the staging S3 create `~/s3-envvars.sh`:
```
export AWS_S3_PRE_CURATE_BUCKET=pdc-describe-staging-precuration
export AWS_S3_POST_CURATE_BUCKET=pdc-describe-staging-postcuration
export AWS_S3_DSPACE_BUCKET=prds-dataspace
export AWS_S3_DSPACE_REGION=us-east-1
# For these last two, open Lastpass and look under `princeton_ansible/RDSS Globus AWS`:
export AWS_S3_KEY_ID=...
export AWS_S3_SECRET_KEY=...
```
Then source this file before starting rails:
```
$ . ~/s3-envvars.sh; bundle exec rails s -p 3000
```

By default `storage.yml` is also configured to use local storage instead of connecting to AWS. Make sure you update your local copy as indicated inside the file if you want to use AWS.

## DataCite integration
We use DataCite to mint DOIs and in production you must to define the `DATACITE_*` environment values indicated [here](https://github.com/pulibrary/princeton_ansible/blob/main/group_vars/pdc_describe/production.yml) for the system to run. During development if you do not set these values the system will use a hard-coded DOI.

## Release and deployment

RDSS uses the same [release and deployment process](https://github.com/pulibrary/rdss-handbook/blob/main/release_process.md) for all projects.

## Sidekiq

Background jobs in staging and production are run via [sidekiq](https://sidekiq.org/). You can go to `https://pdc-describe-staging.princeton.edu/describe/sidekiq` or `https://pdc-describe-prod.princeton.edu/describe/sidekiq` to see the sidekiq dashboard.

Sidekiq jobs are stored in a central redis on pdc-describe-redis-prod1.lib.princeton.edu or pdc-describe-redis-staging1.lib.princeton.edu.  Sidekiq then has workers on each application box working off the list of jobs for staging or production

```mermaid
---
title: Sidekiq Environment
---
graph TD
redis@{ shape: lin-cyl, label: "Central Redis" }
subgraph Application Sever
   rails1[Rails application]
   workers1[Sidekiq Workers] 
end

subgraph Application Sever
   rails2[Rails application]
   workers2[Sidekiq Workers] 
end
rails1 --> redis
rails2 --> redis
workers2 <--> redis
workers1 <--> redis
```

## Mail

### Mail on Development
Mailcatcher is a gem that can also be installed locally.  See the [mailcatcher documentation](https://mailcatcher.me/) for how to run it on your machine.

### Mail on Staging
To See mail that has been sent on the staging server you can utilize capistrano to open up both mailcatcher consoles in your browser.

```
cap staging  mailcatcher:console
```

Look in your default browser for the consoles

### Mail on Production
Emails on production are sent via [Pony Express](https://github.com/pulibrary/pul-it-handbook/blob/f54dfdc7ada1ff993a721f6edb4aa1707bb3a3a5/services/smtp-mail-server.md).

## Admin users in Production
To add a new user as an admin (e.g., so they can migrate data from DataSpace), use the rails console on the production system:
```
irb(main):010:0> user = User.find_by(uid: 'hb0344')
irb(main):015:0> user.add_role(:group_admin, Group.plasma_laboratory)
irb(main):016:0> user.add_role(:group_admin, Group.research_data)
```

## PPPL submitters
To allow a non-admin user to submit only to the PPPL group and its communities and subcommunities, that user's default Group must be set to the Princeton Plasma Physics Lab and their roles must be updated. To do this, use the Rake task `users:make_pppl_user` and pass the `netid` of the user to update:

```
bundle exec rake users:make_pppl_user[xx123]
```

## Viewing the Application outside of the load balancer
To view the application on a specific server you can utilize capistrano to tunnel into the server and open up a browser.

The following would open up a browser to the web application after deploying.  This will allow the developer to verify that the deployment was successful prior to deploying the secondary.
```
cap production_primary application:webapp
```
**Note** to login you must hand edit the response url to have `http` instead of `https`.  Otherwise read operations work fairly well.  Edit (POST/PUT) operations do not seem to work.

## Rolling deployments to production
We utilize rolling deployments to production.  When a new release is ready to deploy
  1. remove the first machine from the loadbalancer
     ```
     cap --hosts=pdc-describe-prod1.princeton.edu production application:remove_from_nginx
     ```
  1. run any ansible updates if needed (Must be setup with pip before running the command below)
     ```
     ansible-playbook playbooks/pdc_describe.yml  --limit pdc-describe-prod1.princeton.edu -e runtime_env=production
     ```
  1. Run capistrano deploy on the first machine        
     ```
     cap --hosts=pdc-describe-prod1.princeton.edu production deploy
     ```
  1. verify that the deployment was successful utilizing capistrano
     ```
     cap  --hosts=pdc-describe-prod1.princeton.edu production application:webapp
     ```
  1. Add the machine back into the loadblancer
     ```
     cap --hosts=pdc-describe-prod1.princeton.edu production application:serve_from_nginx
     ```
    1. remove the secondary machine from the loadbalancer
     ```
     cap --hosts=pdc-describe-prod2.princeton.edu production application:remove_from_nginx
     ```
  1. run any ansible updates if needed (Must be setup with pip before running the command below)
     ```
     ansible-playbook playbooks/pdc_describe.yml  --limit pdc-describe-prod2.princeton.edu -e runtime_env=production
     ```
  1. Run capistrano deploy on the first machine        
     ```
     cap --hosts=pdc-describe-prod2.princeton.edu production deploy
     ```
  1. verify that the deployment was successful utilizing capistrano
     ```
     cap  --hosts=pdc-describe-prod2.princeton.edu production application:webapp
     ```
  1. Add the machine back into the loadblancer
     ```
     cap --hosts=pdc-describe-prod2.princeton.edu production application:serve_from_nginx
     ```
