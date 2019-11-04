class InvoicesController < ApplicationController
  before_action :set_event, only: [:index]

  def all_index
    @invoices = Invoice.all.order(created_at: :desc).includes(:creator)

    authorize Invoice
  end
  
  def index
    @invoices = @event.invoices.order(created_at: :desc)
    authorize @invoices

    # from events controller
    @invoices_being_deposited = (@invoices.where(payout_id: nil, status: 'paid')
      .where
      .not(payout_creation_queued_for: nil) +
      @event.invoices.joins(:payout)
      .where(invoice_payouts: { status: ('in_transit') })
      .or(@event.invoices.joins(:payout).where(invoice_payouts: { status: ('pending') })))

    @stats = {
      total: @invoices.unarchived.sum(:item_amount),
      paid: @invoices.sum(:amount_paid) + @invoices.where.not(manually_marked_as_paid_at: nil).sum(:item_amount),
      pending: @invoices_being_deposited.sum(&:amount_paid),
    }
  end

  def new
    @event = Event.find(params[:event_id])
    @sponsor = Sponsor.new(event: @event)
    @invoice = Invoice.new(sponsor: @sponsor)

    authorize @invoice
  end

  def create
    invoice_params = filtered_params.except(:action, :controller, :sponsor_attributes)
    invoice_params[:item_amount] = (filtered_params[:item_amount].to_f * 100.to_i)

    @event = Event.find params[:event_id]
    sponsor_attributes = filtered_params[:sponsor_attributes].merge(event: @event)

    @sponsor = Sponsor.find_or_initialize_by(id: sponsor_attributes[:id], event: @event)
    @invoice = Invoice.new(invoice_params)
    @invoice.sponsor = @sponsor
    @invoice.creator = current_user

    authorize @invoice

    if @sponsor.update(sponsor_attributes) && @invoice.save
      flash[:success] = "Invoice successfully created and emailed to #{@invoice.sponsor.contact_email}."
      redirect_to @invoice
    else
      render :new
    end
  end

  def show
    @invoice = Invoice.find(params[:id])
    @sponsor = @invoice.sponsor
    @event = @sponsor.event
    @payout = @invoice&.payout
    @refund = @invoice&.fee_reimbursement
    @payout_t = @payout&.t_transaction
    @refund_t = @refund&.t_transaction

    @commentable = @invoice
    @comment = Comment.new
    @comments = @invoice.comments.includes(:user)

    authorize @invoice
  end

  # form for manually marking invoices as paid
  def manual_payment
    @invoice = Invoice.find(params[:invoice_id])

    authorize @invoice
  end

  # actual action for manually marking invoices as paid
  def manually_mark_as_paid
    @invoice = Invoice.find(params[:invoice_id])

    authorize @invoice

    reason = params[:manually_marked_as_paid_reason]
    attachment = params[:manually_marked_as_paid_attachment]

    if @invoice.manually_mark_as_paid(current_user, reason, attachment)
      flash[:success] = 'Manually marked invoice as paid'
      redirect_to @invoice
    else
      render :manual_payment
    end
  end

  def archive
    @invoice = Invoice.find(params[:invoice_id])

    authorize @invoice

    @invoice.archived_at = DateTime.now
    @invoice.archived_by = current_user

    if @invoice.save
      redirect_to @invoice
    else
      flash[:error] = 'Something went wrong while trying to archive this invoice!'
      redirect_to @invoice
    end
  end

  def unarchive
    @invoice = Invoice.find(params[:invoice_id])

    authorize @invoice

    @invoice.archived_at = nil
    @invoice.archived_by = nil

    if @invoice.save
      flash[:success] = 'Invoice has been un-archived.'
      redirect_to @invoice
    else
      flash[:error] = 'Something went wrong while trying to archive this invoice!'
      redirect_to @invoice
    end
  end

  private

  def filtered_params
    params.require(:invoice).permit(
      :due_date,
      :item_description,
      :item_amount,
      :sponsor_id,
      sponsor_attributes: policy(Sponsor).permitted_attributes
    )
  end

  def set_event
    @event = Event.find(params[:id] || params[:event_id])
  end
end
