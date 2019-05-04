class Invoice < ApplicationRecord
  extend FriendlyId

  friendly_id :slug_text, use: :slugged

  # Raise this when attempting to do an operation with the associated Stripe
  # charge, but it doesn't exist, like in the case of trying to create a payout
  # for an invoice that was so low that no charge was created on Stripe's end
  # (ex. for $0.10).
  class NoAssociatedStripeCharge < StandardError; end

  belongs_to :sponsor
  accepts_nested_attributes_for :sponsor

  belongs_to :creator, class_name: 'User'
  belongs_to :manually_marked_as_paid_user, class_name: 'User', required: false
  belongs_to :payout, class_name: 'InvoicePayout', required: false
  belongs_to :fee_reimbursement, required: false

  has_one_attached :manually_marked_as_paid_attachment

  has_many :comments, as: :commentable

  enum status: {
    draft: 'draft',
    open: 'open',
    paid: 'paid',
    void: 'void',
    uncollectible: 'uncollectible'
  }

  validates_presence_of :item_description, :item_amount, :due_date

  # all manually_marked_as_paid_... fields must be present all together or not
  # present at all
  validates_presence_of :manually_marked_as_paid_user, :manually_marked_as_paid_reason,
                        if: -> { !self.manually_marked_as_paid_at.nil? }
  validates_absence_of :manually_marked_as_paid_user, :manually_marked_as_paid_reason,
                       if: -> { self.manually_marked_as_paid_at.nil? }

  # all payout_creation... fields must be present all together or not at all
  validates_presence_of :payout_creation_queued_for,
                        :payout_creation_queued_job_id, :payout_creation_balance_available_at,
                        if: -> { !self.payout_creation_queued_at.nil? }
  validates_absence_of :payout_creation_queued_for,
                       :payout_creation_queued_job_id, :payout_creation_balance_available_at,
                       if: -> { self.payout_creation_queued_at.nil? }

  validate :due_date_cannot_be_in_past, on: :create

  before_create :set_defaults

  # Stripe syncing…
  before_create :create_stripe_invoice
  before_destroy :close_stripe_invoice

  after_update :send_payment_notification_if_needed

  def state
    if self&.payout&.t_transaction
      :success
    elsif paid?
      :info
    elsif due_date < Time.current
      :pending
    elsif due_date < 3.days.from_now
      :warning
    else
      :muted
    end
  end

  def state_text
    if self&.payout&.t_transaction
      'Paid'
    elsif paid?
      'Pending'
    elsif due_date < Time.current
      'Overdue'
    elsif due_date < 3.days.from_now
      'Due soon'
    else
      'Sent'
    end
  end

  def filter_data
    {
      exists: true,
      paid: paid?,
      unpaid: !paid?,
      upcoming: due_date > 3.days.from_now,
      overdue: due_date < 3.days.from_now
    }
  end

  # Manually mark this invoice as paid (probably in the case of a physical
  # check being sent to pay it). This marks the corresponding payment on Stripe
  # as paid and stores some metadata about why it was marked as paid.
  def manually_mark_as_paid(user_who_did_it, reason_for_manual_payment, attachment = nil)
    self.manually_marked_as_paid_at = Time.current
    self.manually_marked_as_paid_user = user_who_did_it
    self.manually_marked_as_paid_reason = reason_for_manual_payment
    self.manually_marked_as_paid_attachment = attachment

    return false unless self.valid?

    inv = StripeService::Invoice.retrieve(stripe_invoice_id)
    inv.paid = true

    if inv.save
      self.set_fields_from_stripe_invoice(inv)

      if self.save
        true
      else
        false
      end
    else
      errors.add(:base, 'failed to save with vendor')

      false
    end
  end

  def manually_marked_as_paid?
    self.manually_marked_as_paid_at.present?
  end

  def queue_payout!
    inv = StripeService::Invoice.retrieve(id: stripe_invoice_id, expand: ['charge.balance_transaction'])
    raise NoAssociatedStripeCharge if inv.charge.nil?

    b_tnx = inv.charge.balance_transaction

    funds_available_at = Util.unixtime(b_tnx.available_on)
    create_payout_at = funds_available_at + 1.day

    job = CreateInvoicePayoutJob.set(wait_until: create_payout_at).perform_later(self)

    self.payout_creation_queued_at = Time.current
    self.payout_creation_queued_for = create_payout_at
    self.payout_creation_queued_job_id = job.job_id
    self.payout_creation_balance_net = b_tnx.net # amount to pay out
    self.payout_creation_balance_stripe_fee = b_tnx.fee
    self.payout_creation_balance_available_at = funds_available_at

    self.save!
  end

  def create_payout!
    inv = StripeService::Invoice.retrieve(id: stripe_invoice_id, expand: ['charge.balance_transaction'])

    raise StandardError, 'Funds not yet available' unless Time.current.to_i > inv.charge.balance_transaction.available_on

    self.payout = InvoicePayout.new(
      amount: self.payout_creation_balance_net,
      invoice: self
    )

    self.fee_reimbursement = FeeReimbursement.new(
      invoice: self
    )

    self.fee_reimbursement.save

    # if a transfer takes longer than 5 days something is probably wrong. so send an email
    fee_reimbursement_job = SendUnmatchedFeeReimbursementEmailJob.set(wait_until: DateTime.now + 5.days).perform_later(self.fee_reimbursement)
    self.fee_reimbursement.mailer_queued_job_id = fee_reimbursement_job.provider_job_id

    self.fee_reimbursement.save

    self.save!
  end

  def set_fields_from_stripe_invoice(inv)
    self.amount_due = inv.amount_due,
                      self.amount_paid = inv.amount_paid
    self.amount_remaining = inv.amount_remaining
    self.attempt_count = inv.attempt_count
    self.attempted = inv.attempted
    self.stripe_charge_id = inv.charge
    self.auto_advance = inv.auto_advance
    self.memo = inv.description
    self.due_date = Time.at(inv.due_date).to_datetime # convert from unixtime
    self.ending_balance = inv.ending_balance
    self.finalized_at = inv.finalized_at
    self.hosted_invoice_url = inv.hosted_invoice_url
    self.invoice_pdf = inv.invoice_pdf
    self.number = inv.number
    self.starting_balance = inv.starting_balance
    self.statement_descriptor = inv.statement_descriptor
    self.subtotal = inv.subtotal
    self.tax = inv.tax
    self.tax_percent = inv.tax_percent
    self.total = inv.total
    self.status = inv.status
  end

  def stripe_dashboard_url
    url = 'https://dashboard.stripe.com'

    if StripeService.mode == :test
      url += '/test'
    end

    url += "/invoices/#{self.stripe_invoice_id}"

    url
  end

  def event
    self.sponsor.event
  end

  def fee_reimbursed?
    !fee_reimbursement.nil?
  end

  private

  def set_defaults
    event = self.sponsor.event.name
    self.memo = "To support #{event}. #{event} is fiscally sponsored by The Hack Foundation (d.b.a. Hack Club), a 501(c)(3) nonprofit with the EIN 81-2908499."

    self.auto_advance = true
  end

  def due_date_cannot_be_in_past
    if due_date.present? && due_date < Time.current
      errors.add(:due_date, "can't be in the past")
    end
  end

  def create_stripe_invoice
    item = StripeService::InvoiceItem.create(stripe_invoice_item_params)
    self.item_stripe_id = item.id

    inv = StripeService::Invoice.create(stripe_invoice_params)
    self.stripe_invoice_id = inv.id

    inv.send_invoice

    self.set_fields_from_stripe_invoice(inv)
  end

  def close_stripe_invoice
    invoice = StripeService::Invoice.retrieve(stripe_invoice_id)
    invoice.void_invoice

    self.set_fields_from_stripe_invoice invoice
  end

  def send_payment_notification_if_needed
    return unless saved_changes[:status].present?

    was = saved_changes[:status][0] # old value of status
    now = saved_changes[:status][1] # new value of status

    if was != 'paid' && now == 'paid'
      # send special email on first invoice paid
      if self.sponsor.event.invoices.select { |i| i.status == 'paid' }.count == 1
        InvoiceMailer.with(invoice: self).first_payment_notification.deliver_later
        return
      end

      InvoiceMailer.with(invoice: self).payment_notification.deliver_later
    end
  end

  def stripe_invoice_item_params
    {
      customer: self.sponsor.stripe_customer_id,
      currency: 'usd',
      description: self.item_description,
      amount: self.item_amount
    }
  end

  def stripe_invoice_params
    {
      customer: self.sponsor.stripe_customer_id,
      auto_advance: self.auto_advance,
      billing: 'send_invoice',
      due_date: self.due_date.to_i, # convert to unixtime
      description: self.memo,
      status: self.status,
      statement_descriptor: self.statement_descriptor,
      tax_percent: self.tax_percent
    }
  end

  def slug_text
    "#{self.sponsor.name} #{self.item_description}"
  end
end
