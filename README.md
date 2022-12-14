# pdc_describe
Cataloging application for PDC content and more

[![CircleCI](https://circleci.com/gh/pulibrary/pdc_describe/tree/main.svg?style=svg)](https://circleci.com/gh/pulibrary/pdc_describe/tree/main)
[![Coverage Status](https://coveralls.io/repos/github/pulibrary/pdc_describe/badge.svg?branch=main)](https://coveralls.io/github/pulibrary/pdc_describe?branch=main)

## Dependencies
* Ruby: 3.0.3
* nodejs: 16.15.0
* yarn: 1.22.18
* Lando: 3.6.2

## Local development

### Setup
1. Check out code and `cd`
1. Install tool dependencies
    1. [Lando](https://docs.lando.dev/getting-started/installation.html)
    1. [asdf](https://asdf-vm.com/guide/getting-started.html#_2-download-asdf)
1. Install asdf dependencies
    1. `asdf plugin add ruby`
    1. `asdf plugin add node`
    1. `asdf plugin add yarn`
    1. `asdf install`
    1. ... but because asdf is not a dependency manager, if there are errors, you may need to install other dependencies. For example: `brew install gpg`
1. Install language-specific dependencies
    1. `bundle install`
    1. `yarn install`

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

### Development with AWS resources
Tests should never depend on outside resources, and it's best minimize dependencies during development, too, but it can be useful. To give your local instance access to the staging S3 create `~/s3-envvars.sh`:
```
export AWS_S3_PRE_CURATE_BUCKET=pdc-describe-staging-precuration
export AWS_S3_POST_CURATE_BUCKET=pdc-describe-staging-postcuration
# For these last two, open Lastpass and look under `princeton_ansible/RDSS Globus AWS`:
export AWS_S3_KEY_ID=...
export AWS_S3_SECRET_KEY=...
```
Then source this file before starting rails:
```
$ . ~/s3-envvars.sh; bundle exec rails s -p 3000
```

## DataCite integration
We use DataCite to mint DOIs and in production you must to define the `DATACITE_*` environment values indicated [here](https://github.com/pulibrary/princeton_ansible/blob/main/group_vars/pdc_describe/production.yml) for the system to run. During development if you do not set these values the system will use a hard-coded DOI.

## Release and deployment

RDSS uses the same [release and deployment process](https://github.com/pulibrary/rdss-handbook/blob/main/release_process.md) for all projects.

## Mail on Staging
To See mail that has been sent on the staging server you must ssh tunnel into the server.  Since there are two staging servers, the mail could have been sent on either machine. You may have to check both and will need two terminals.

* terminal 1
`ssh -L 1082:localhost:1080 pulsys@pdc-describe-staging1`
* terminal 2
`ssh -L 1083:localhost:1080 pulsys@pdc-describe-staging2`

Once the tunnel is open you can see the mail that has been sent on [staging1 here](http://localhost:1082/) and on [staging 2 here](http://localhost:1083/)


## Design
An early stages Entity-Relationship Diagram (ERD) is available in [this Google Doc](https://docs.google.com/drawings/d/1q2sfj8rrcNVgqQPK5uT_t79A9SYqncinh3HbnCSGMyQ/edit).

### Sample Data
Sample data available here: https://docs.google.com/document/d/18ZkBldqWxIIR1UA6qMY87RnGFTKU9HG3EJzodzzFf2A/edit
