# frozen_string_literal: true
server "pdc-describe-staging1.princeton.edu", user: "deploy", roles: %w[app db web one]
server "pdc-describe-staging2.princeton.edu", user: "deploy", roles: %w[app db web cron two]
