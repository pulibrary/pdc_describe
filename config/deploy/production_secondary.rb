# frozen_string_literal: true
server "pdc-describe-prod2.princeton.edu", user: "deploy", roles: %w[app db web]
server "pdc-describe-prod3.princeton.edu", user: "deploy", roles: %w[app db web]
