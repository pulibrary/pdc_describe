# frozen_string_literal: true
# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever
set :output, "/opt/pdc_describe/shared/cron.log"
job_type :restart_passenger, "sudo service nginx restart :output"

every :day, at: "12:05am", roles: [:cron] do
  rake "embargo:release"
end

every :day, at: "12:05am", roles: [:one] do
  restart_passenger "na"
end

every :day, at: "12:15am", roles: [:two] do
  restart_passenger "na"
end

every :day, at: "12:30am", roles: [:three] do
  restart_passenger "na"
end
