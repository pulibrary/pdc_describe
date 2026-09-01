# frozen_string_literal: true
source "https://rubygems.org"

gem "aasm"
gem "actioncable"
gem "addressable", ">= 2.9.0"
gem "amazing_print"
gem "aws-sdk-s3"
# https://github.com/sul-dlss/cocina-models
# Required by latest datacite library
gem "bootsnap", ">= 1.4.4", require: false
gem "cocina-models"
gem "csv"
gem "datacite", github: "sul-dlss/datacite-ruby", branch: "main"
gem "datacite-mapping"
gem "devise", ">= 5.0.4"
gem "dogstatsd-ruby"
gem "faraday"
gem "flipflop"
gem "friendly_id", "~> 5.4.0"
gem "health-monitor-rails", "~>12.0"
gem "honeybadger"
gem "io-wait", "0.2.1"
gem "jbuilder", "~> 2.7"
gem "kramdown"
gem "listen", "~> 3.3"
gem "net-ftp"
gem "net-imap"
gem "net-pop"
gem "net-smtp"
gem "net-ssh", "~> 7.0"
gem "nokogiri", ">= 1.19.3"
gem "omniauth", "~> 2.1", ">= 2.1.2"
gem "omniauth-cas", "~> 3.0"
gem "pg"
gem "puma"
gem "rails", "~>8.0"
gem "rails_semantic_logger"
gem "redis", "~> 4.0"
gem "retryable"
gem "rinku"
gem "rolify"
gem "rspec-rails"
gem "sass-rails"
gem "sidekiq", "< 9"
gem "turbolinks", "~> 5"
gem "vite_rails"
gem "whenever"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem "ezid-client", git: "https://github.com/duke-libraries/ezid-client.git", ref: "dfcf7f49995560ed48df407560c4fe3fb6dbfa7b"

group :development, :test do
  gem "bcrypt_pbkdf"
  gem "benchmark"
  gem "bixby"
  gem "byebug"
  gem "coveralls_reborn", "~> 0.28"
  gem "ed25519"
  gem "equivalent-xml", "~> 0.6.0"
  gem "pry-byebug"
  gem "pry-rails"
  gem "simplecov", "~> 0.22"
  gem "tzinfo-data", platforms: [:windows]
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
  gem "rack-mini-profiler", "~> 2.0"
  gem "sqlite3", force_ruby_platform: true # requires bundler >= 2.3.18
end

group :test do
  gem "axe-core-rspec"
  gem "capybara"
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
