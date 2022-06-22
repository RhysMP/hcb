# frozen_string_literal: true

# == Schema Information
#
# Table name: canonical_pending_settled_mappings
#
#  id                               :bigint           not null, primary key
#  created_at                       :datetime         not null
#  updated_at                       :datetime         not null
#  canonical_pending_transaction_id :bigint           not null
#  canonical_transaction_id         :bigint           not null
#
# Indexes
#
#  index_canonical_pending_settled_map_on_canonical_pending_tx_id  (canonical_pending_transaction_id)
#  index_canonical_pending_settled_mappings_on_canonical_tx_id     (canonical_transaction_id)
#
# Foreign Keys
#
#  fk_rails_...  (canonical_pending_transaction_id => canonical_pending_transactions.id)
#  fk_rails_...  (canonical_transaction_id => canonical_transactions.id)
#
class CanonicalPendingSettledMapping < ApplicationRecord
  belongs_to :canonical_pending_transaction
  belongs_to :canonical_transaction

end
