# frozen_string_literal: true

module Partners
  module Google
    module GSuite
      class DeleteDomain
        include Partners::Google::GSuite::Shared::DirectoryClient

        def initialize(domain:)
          @domain = domain
        end

        def run
          unless Rails.env.production?
            puts "☣️ In production, we would currently be updating the GSuite on Google Admin ☣️"
            return
          end

          directory_client.delete_domain(gsuite_customer_id, @domain)
        end

      end
    end
  end
end
