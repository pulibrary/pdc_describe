# config valid for current version and patch releases of Capistrano
lock "~> 3.17.0"

set :application, "pdc_describe"
set :repo_url, "https://github.com/pulibrary/pdc_describe.git"

set :linked_dirs, %w(log public/system public/assets)

# Default branch is :main
set :branch, ENV["BRANCH"] || "main"

set :deploy_to, "/opt/pdc_describe"
