# frozen_string_literal: true

module TransactionEngine
  module CanonicalTransactionService
    module Import
      class StripeThatLookLikeDuplicates
        def run
          unprocessed_stripe_with_duplicate_hashes.find_each(batch_size: 100) do |ht|
            attrs = {
              date: ht.date,
              memo: ht.memo,
              amount_cents: ht.amount_cents,
              canonical_hashed_mappings: [CanonicalHashedMapping.new(hashed_transaction: ht)]
            }
            ::CanonicalTransaction.create!(attrs)
          end
        end

        private

        def unprocessed_stripe_with_duplicate_hashes
          stripe_hts.where("id in (?)", diff_ht_ids)
        end

        def diff_ht_ids
          @diff_ht_ids ||= duplicate_ht_ids - previously_processed_ht_ids
        end

        def stripe_hts
          ::HashedTransaction.where.not(raw_stripe_transaction_id: nil)
        end

        def duplicate_ht_ids
          @duplicate_ht_ids ||= ::TransactionEngine::HashedTransactionService::Duplicates.new.run.pluck(:id)
        end

        def previously_processed_ht_ids
          @previously_processed_ht_ids ||= ::CanonicalHashedMapping.pluck(:hashed_transaction_id)
        end

      end
    end
  end
end
