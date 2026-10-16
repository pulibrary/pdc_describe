# frozen_string_literal: true

require "omniauth-entra-id"

module OmniAuth
  module Strategies
    # Entra ID through the Microsoft identity platform v2 endpoints.
    # Entra evaluates Conditional Access on the authorize request.
    class EntraGraph < EntraId
      option :name, "entra_id"

      GRAPH_SCOPE = "openid profile email https://graph.microsoft.com/User.Read"

      def client
        options.tenant_provider = EntraGraphProvider
        super
      end
    end

    # Supplies client credentials and the Graph OAuth endpoints to EntraGraph.
    class EntraGraphProvider
      BASE_URL = "https://login.microsoftonline.com"

      def initialize(strategy)
        @strategy = strategy
      end

      def client_id
        credential("ENTRA_CLIENT_ID")
      end

      def client_secret
        credential("ENTRA_CLIENT_SECRET")
      end

      # Tenant is optional. A blank value uses the Entra "common" endpoint.
      def tenant_id
        ENV["ENTRA_TENANT_ID"].presence || EntraId::COMMON_TENANT_ID
      end

      def base_url
        BASE_URL
      end

      def scope
        EntraGraph::GRAPH_SCOPE
      end

      private

        def credential(key)
          value = ENV[key]
          return value if value.present?

          raise KeyError, "#{key} is required to sign in with Entra ID"
        end
    end
  end
end
