# pdc_describe

Cataloging application for PDC content and more

[![CircleCI](https://circleci.com/gh/pulibrary/pdc_describe/tree/main.svg?style=svg)](https://circleci.com/gh/pulibrary/pdc_describe/tree/main)
[![Coverage Status](https://coveralls.io/repos/github/pulibrary/pdc_describe/badge.svg?branch=main)](https://coveralls.io/github/pulibrary/pdc_describe?branch=main)

## Dependencies

- Ruby: 3.0.3
- nodejs: 16.15.0
- yarn: 1.22.18
- Lando: 3.6.2

## Local development

### Setup

1. Check out code
2. `bundle install`
3. `yarn install`

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

## DataCite integration

We use DataCite to mint DOIs and in production you must to define the `DATACITE_*` environment values indicated [here](https://github.com/pulibrary/princeton_ansible/blob/main/group_vars/pdc_describe/production.yml) for the system to run. During development if you do not set these values the system will use a hard-coded DOI.

## Deploying

pulbot: `pulbot deploy pdc_describe to [staging|production]`

To create a tagged release use the [steps in the RDSS handbook](https://github.com/pulibrary/rdss-handbook/blob/main/release_process.md)

## Design

An early stages Entity-Relationship Diagram (ERD) is available in [this Google Doc](https://docs.google.com/drawings/d/1q2sfj8rrcNVgqQPK5uT_t79A9SYqncinh3HbnCSGMyQ/edit).

### Sample Data

Sample data available here: https://docs.google.com/document/d/18ZkBldqWxIIR1UA6qMY87RnGFTKU9HG3EJzodzzFf2A/edit
