# frozen_string_literal: true
source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem "aasm"
gem "amazing_print"
gem "aws-sdk-s3"
gem "datacite-mapping"
gem "dogstatsd-ruby"
gem "health-monitor-rails"
gem "honeybadger"
gem "io-wait", "0.2.1"
gem "net-ftp"
gem "net-imap"
gem "net-pop"
gem "net-ssh", "7.0.0.beta1"
# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
gem "rails", "~> 6.1.7"
# Use sqlite3 as the database for Active Record
gem "pg"
# Use Puma as the app server
gem "puma", "~> 5.6"
# Use SCSS for stylesheets
gem "sass-rails", ">= 6"
# Turbolinks makes navigating your web application faster. Read more: https://github.com/turbolinks/turbolinks
gem "turbolinks", "~> 5"
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem "jbuilder", "~> 2.7"
# Use Redis adapter to run Action Cable in production
gem "redis", "~> 4.0"
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'
gem "nokogiri", ">= 1.13.4"
gem "retryable"
gem "rolify"
gem "rspec-rails", "~> 5.0.0"
gem "sidekiq", "~> 7.2"
gem "simplecov", require: false
gem "vite_rails", "3.0.12"
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

gem "faraday"

gem "datacite", github: "sul-dlss/datacite-ruby", branch: "main"

gem "kramdown"

gem "net-smtp"
gem "rinku"

group :development, :test do
  gem "bcrypt_pbkdf"
  gem "bixby"
  gem "byebug"
  gem "ed25519"
  gem "equivalent-xml", "~> 0.6.0"
  gem "pry-byebug"
  gem "pry-rails"
  gem "yard"
end

group :development do
  gem "capistrano", "~> 3.10", require: false
  gem "capistrano-passenger", require: false
  gem "capistrano-rails", "~> 1.4", require: false
  gem "foreman"
  gem "mailcatcher"
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem "web-console", ">= 4.1.0"
  # Display performance information such as SQL time and flame graphs for each request in your browser.
  # Can be configured to work on production as well see: https://github.com/MiniProfiler/rack-mini-profiler/blob/master/README.md
  gem "listen", "~> 3.3"
  gem "rack-mini-profiler", "~> 2.0"
end

group :test do
  gem "axe-core-rspec"
  gem "capybara"
  gem "coveralls_reborn", require: false
  gem "database_cleaner-active_record"
  gem "factory_bot_rails", require: false
  gem "ffaker"
  gem "rails-controller-testing"
  gem "rspec-html-matchers"
  gem "rspec-retry"
  gem "selenium-webdriver"
  gem "sinatra"
  gem "webmock"
end

group :staging, :production do
  gem "ddtrace", require: "ddtrace/auto_instrument"
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]
