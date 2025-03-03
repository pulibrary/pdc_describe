# frozen_string_literal: true

set :application, "pdc_describe"
set :repo_url, "https://github.com/pulibrary/pdc_describe.git"

set :linked_dirs, %w[log /opt/pdc_describe/shared/system /opt/pdc_describe/shared/assets node_modules]

# Default branch is :main
set :branch, ENV["BRANCH"] || "main"

set :deploy_to, "/opt/pdc_describe"

set :rails_env, :production if fetch(:stage).to_s.start_with?("production")

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

namespace :application do
  desc "Opens the application web app without the load balancer"
  task :webapp do
    on roles(:app) do |host|
      app_host = host.hostname
      user = "pulsys"
      port = rand(9000..9999)
      puts "Opening #{app_host} application on port #{port} as user #{user}"
      Net::SSH.start(app_host, user) do |session|
        session.forward.local(port, "localhost", 80)
        puts "Press Ctrl+C to end the application connection"
        `open http://localhost:#{port}/describe`
        session.loop(0.1) { true }
      end
    end
  end

  # You can/ should apply this command to a single host
  # cap --hosts=pdc-describe-staging1.princeton.edu staging application:remove_from_nginx
  desc "Marks the server(s) to be removed from the loadbalancer"
  task :remove_from_nginx do
    count = 0
    on roles(:app) do
      count += 1
    end
    if count > 1
      raise "You must run this command on individual servers utilizing the --hosts= switch"
    end
    on roles(:app) do
      within release_path do
        execute :touch, "/opt/pdc_describe/shared/remove-from-nginx"
      end
    end
  end

  # You can/ should apply this command to a single host
  # cap --hosts=pdc-describe-staging1.princeton.edu staging application:serve_from_nginx
  desc "Marks the server(s) to be removed from the loadbalancer"
  task :serve_from_nginx do
    on roles(:app) do
      within release_path do
        execute :rm, "-f /opt/pdc_describe/shared/remove-from-nginx"
      end
    end
  end
end

before "deploy:reverted", "deploy:assets:precompile"

# rubocop:enable Rails/Output
