# frozen_string_literal: true

set :application, "pdc_describe"
set :repo_url, "https://github.com/pulibrary/pdc_describe.git"

set :linked_dirs, %w[log public/system public/assets node_modules]

# Default branch is :main
set :branch, ENV["BRANCH"] || "main"

set :deploy_to, "/opt/pdc_describe"

# Workaround for this issue: https://github.com/capistrano/rails/issues/235
Rake::Task["deploy:assets:backup_manifest"].clear_actions
Rake::Task["deploy:assets:restore_manifest"].clear_actions

namespace :sidekiq do
  task :restart do
    on roles(:app) do
      execute :sudo, :service, "sidekiq-workers", :restart
    end
  end
end

after "passenger:restart", "sidekiq:restart"

# rubocop:disable Rails/Output
namespace :sidekiq do
  desc "Opens Sidekiq Consoles"
  task :console do
    on roles(:app) do |host|
      sidekiq_host = host.hostname
      user = "pulsys"
      port = rand(9000..9999)
      puts "Opening #{sidekiq_host} Sidekiq Console on port #{port} as user #{user}"
      Net::SSH.start(sidekiq_host, user) do |session|
        session.forward.local(port, "localhost", 80)
        puts "Press Ctrl+C to end Console connection"
        `open http://localhost:#{port}/describe/sidekiq`
        session.loop(0.1) { true }
      end
    end
  end
end

namespace :mailcatcher do
  desc "Opens Mailcatcher Consoles"
  task :console do
    on roles(:app) do |host|
      mail_host = host.hostname
      user = "pulsys"
      port = rand(9000..9999)
      puts "Opening #{mail_host} Mailcatcher Console on port #{port} as user #{user}"
      Net::SSH.start(mail_host, user) do |session|
        session.forward.local(port, "localhost", 1080)
        puts "Press Ctrl+C to end Console connection"
        `open http://localhost:#{port}/`
        session.loop(0.1) { true }
      end
    end
  end
end

before "deploy:reverted", "deploy:assets:precompile"

# rubocop:enable Rails/Output
