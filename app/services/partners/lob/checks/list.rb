# frozen_string_literal: true

module Partners
  module Lob
    module Checks
      class List
        include ::Partners::Lob::Shared

        def initialize(start_date: nil)
          @start_date = start_date || Time.now.utc - 1.month
        end

        def run
          lob_checks
        end

        private

        def lob_checks
          resp = fetch_checks

          ts = resp["data"]

          while resp["next_url"]

            parsed = Rack::Utils.parse_nested_query resp.next_url

            after = parsed["after"]

            resp = fetch_checks(after: after)

            ts += resp["data"]
          end

          ts
        end

        def fetch_checks(after: nil)
          client.checks.list(list_attrs(after: after))
        end

        def list_attrs(after:)
          {
            :after => after,
            :date_created => { gte: date_created_gte },
            :limit => 100,
            "include[]" => "total_count"
          }.compact
        end

        def date_created_gte
          @start_date.to_date.to_s
        end
      end
    end
  end
end
