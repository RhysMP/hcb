# frozen_string_literal: true

module RecurringDonationService
  class HandleInvoicePaid
    def initialize(stripe_invoice)
      @stripe_invoice = stripe_invoice
    end

    def run
      recurring_donation = RecurringDonation.find_by(stripe_subscription_id: @stripe_invoice.subscription)
      return unless recurring_donation

      donation = recurring_donation.donations.build(
        aasm_state: :in_transit,
        amount: @stripe_invoice.amount_due,
        amount_received: @stripe_invoice.amount_paid,
        event: recurring_donation.event,
        stripe_payment_intent_id: @stripe_invoice.payment_intent
      )

      donation.set_fields_from_stripe_payment_intent(StripeService::PaymentIntent.retrieve(@stripe_invoice.payment_intent))

      donation.save!

      DonationService::Queue.new(donation_id: donation.id).run

      donation.send_receipt!

      # Import the donation onto the ledger
      rpdt = ::PendingTransactionEngine::RawPendingDonationTransactionService::Donation::ImportSingle.new(donation: donation).run
      cpt = ::PendingTransactionEngine::CanonicalPendingTransactionService::ImportSingle::Donation.new(raw_pending_donation_transaction: rpdt).run
      ::PendingEventMappingEngine::Map::Single::Donation.new(canonical_pending_transaction: cpt).run
    end

  end
end
