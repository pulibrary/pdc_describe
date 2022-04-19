# pdc_describe
Cataloging application for PDC content and more

[![CircleCI](https://circleci.com/gh/pulibrary/pdc_describe/tree/main.svg?style=svg)](https://circleci.com/gh/pulibrary/pdc_describe/tree/main)
[![Coverage Status](https://coveralls.io/repos/github/pulibrary/pdc_describe/badge.svg?branch=main)](https://coveralls.io/github/pulibrary/pdc_describe?branch=main)

## Dependencies
* Ruby: 3.0.3
* nodejs: lts-fermium
* yarn: 1.22.18
* Lando: 3.6.2

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
*`foreman` is used to enable [Hot Module Replacement for Webpack](https://webpack.js.org/concepts/hot-module-replacement/).*

1. `bundle exec foreman start`
2. Access application at [http://localhost:3000/](http://localhost:3000/)

You can also use two terminal windows instead of `foreman` to start the Rails application and the Webpack server.
This is convenient when you need to step through the code as `byebug` does not always show the prompt when using `foreman`.

1. Terminal one: `bin/rails s -p 3000`
2. Terminal two: `bin/webpack-dev-server`
3. Access pdc_describe at [http://localhost:3000/](http://localhost:3000/)

## Deploying
pulbot: `pulbot deploy pdc_describe to [staging|production]`

To create a tagged release use the [steps in the RDSS handbook](https://github.com/pulibrary/rdss-handbook/blob/main/release_process.md)


## Design
An early stages Entity-Relationship Diagram (ERD) is available in [this Google Doc](https://docs.google.com/drawings/d/1q2sfj8rrcNVgqQPK5uT_t79A9SYqncinh3HbnCSGMyQ/edit).
