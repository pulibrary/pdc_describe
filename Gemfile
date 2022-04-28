# frozen_string_literal: true
source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem "aws-sdk-s3"
gem "factory_bot_rails", require: false
gem "honeybadger", "~> 4.0"
# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
gem "rails", "~> 6.1.3", ">= 6.1.3.2"
# Use sqlite3 as the database for Active Record
gem "pg"
# Use Puma as the app server
gem "puma", "~> 5.0"
# Use SCSS for stylesheets
gem "sass-rails", ">= 6"
# Transpile app-like JavaScript. Read more: https://github.com/rails/webpacker
gem "webpacker", "~> 5.0"
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem "turbolinks", "~> 5"
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem "jbuilder", "~> 2.7"
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'
gem "rspec-rails", "~> 5.0.0"
gem "whenever"

# Reference: https://github.com/pulibrary/pul-the-hard-way/blob/main/services/cas.md
gem "devise"
gem "omniauth-cas"

# Use Active Storage variant
# gem 'image_processing', '~> 1.2'

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", ">= 1.4.4", require: false

# EZID client from Duke since it has been upgraded to support Ruby 3.
gem "ezid-client", git: "https://github.com/duke-libraries/ezid-client.git", ref: "dfcf7f49995560ed48df407560c4fe3fb6dbfa7b"

gem "friendly_id", "~> 5.4.0"

group :development, :test do
  gem "bixby"
  gem "byebug"
  gem "ffaker"
  gem "pry-byebug"
  gem "pry-rails"
end

group :development do
  gem "capistrano", "~> 3.10", require: false
  gem "capistrano-passenger", require: false
  gem "capistrano-rails", "~> 1.4", require: false
  gem "foreman"
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem "web-console", ">= 4.1.0"
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  gem "listen", "~> 3.3"
  gem "rack-mini-profiler", "~> 2.0"
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem "spring"
end

group :test do
  gem "axe-core-rspec"
  # Adds support for Capybara system testing and selenium driver
  gem "capybara", ">= 3.26"
  gem "coveralls_reborn", "~> 0.24", require: false
  gem "selenium-webdriver"
  # Use simplecov for coverage analysis
  gem "simplecov", require: false
  # Used for detecting what a controller rendered
  gem "rails-controller-testing"
  # Easy installation and use of web drivers to run system tests with browsers
  gem "webdrivers"
  gem "webmock"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]
