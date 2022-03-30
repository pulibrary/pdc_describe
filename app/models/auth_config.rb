# frozen_string_literal: true

# Source: https://curationexperts.github.io/recipes/authentication/shibboleth_and_hyrax.html
class AuthConfig
    # In production, we use Shibboleth for user authentication,
    # but in development mode, you may want to use local database
    # authentication instead.
    def self.use_database_auth?
      return false if Rails.env.production?
      true
    end
  end
