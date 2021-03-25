class CanonicalPendingTransactionsController < ApplicationController
  def show
    @canonical_pending_transaction = CanonicalPendingTransaction.find(params[:id])
    authorize @canonical_pending_transaction

    # Comments
    @hcb_code = HcbCode.find_by(hcb_code: @canonical_pending_transaction.hcb_code)
  end
end
