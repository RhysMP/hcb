module TransactionEngine
  module CanonicalTransactionService
    module MapToEvent
      class Process
        def run
          likely_githubs.find_each do |ct|

            ::TransactionEngine::CanonicalTransactionService::MapToEvent::Github.new(canonical_transaction: ct).run

          end
        end

        private

        def likely_githubs
          ::CanonicalTransaction.exclude(excluded_ids).likely_github
        end

        def excluded_ids
          @excluded_ids ||= ::CanonicalEventMapping.pluck(:canonical_transaction_id)
        end
      end
    end
  end
end
