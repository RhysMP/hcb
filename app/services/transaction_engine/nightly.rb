# frozen_string_literal: true

module TransactionEngine
  class Nightly
    include ::TransactionEngine::Shared

    def initialize(start_date: nil)
      @start_date = start_date || 1.week.ago
    end

    def run
      # (1) Import transactions
      try_to { import_raw_plaid_transactions! }
      try_to { import_other_raw_plaid_transactions! }
      # import_raw_emburse_transactions! TODO: remove completely
      try_to { import_raw_stripe_transactions! }
      try_to { import_raw_csv_transactions! }
      try_to { import_raw_increase_transactions! }
      try_to { import_raw_column_transactions! }

      # (2) Hash transactions
      try_to { hash_raw_plaid_transactions! }
      # hash_raw_emburse_transactions! TODO: remove completely
      try_to { hash_raw_stripe_transactions! }
      try_to { hash_raw_csv_transactions! }
      try_to { hash_raw_increase_transactions! }

      # (3) Canonize transactions
      try_to { canonize_hashed_transactions! }

      # (4) Fix plaid mistakes
      fix_plaid_mistakes!

      # (5) Fix memo mistakes
      try_to { fix_memo_mistakes! }
    end

    private

    def import_raw_plaid_transactions!
      BankAccount.syncing_v2.pluck(:id).each do |bank_account_id|
        begin
          puts "raw_plaid_transactions: #{bank_account_id}"

          ::TransactionEngine::RawPlaidTransactionService::Plaid::Import.new(bank_account_id:, start_date: @start_date).run
        rescue => e
          Airbrake.notify(e)
        end
      end
    end

    def import_other_raw_plaid_transactions!
      ::TransactionEngine::RawPlaidTransactionService::BankAccount1::Import.new(start_date: @start_date).run
      ::TransactionEngine::RawPlaidTransactionService::BankAccount9::Import.new(start_date: @start_date).run
    end

    def calculate_n_times
      (((Time.now.utc - @start_date) / 1.day).ceil / 15.0).ceil + 1 # number of 15 days periods plus add an additional day
    end

    def import_raw_emburse_transactions!
      # Check for TXs in 1 month blocks over the past n periods at increments of 15 days
      calculate_n_times.times do |n|
        from = Date.today - (n * 15).days
        to = from + 15.days

        puts "raw_emburse_transactions: #{from} - #{to}"

        begin
          ::TransactionEngine::RawEmburseTransactionService::Emburse::Import.new(start_date: from, end_date: to).run
        rescue => e
          puts e
        end
      end
    end

    def import_raw_stripe_transactions!
      ::TransactionEngine::RawStripeTransactionService::Stripe::Import.new(start_date: @start_date).run
    end

    def import_raw_csv_transactions!
      ::TransactionEngine::RawCsvTransactionService::Import.new.run
    end

    def import_raw_increase_transactions!
      ::TransactionEngine::RawIncreaseTransactionService::Increase::Import.new(start_date: @start_date).run
    end

    def import_raw_column_transactions!
      transactions_by_report = ColumnService.new.transactions(from_date: @start_date)

      transactions_by_report.each do |report_id, transactions|
        transactions.each_with_index do |transaction, transaction_index|
          raw_column_transaction = RawColumnTransaction.find_or_create_by(column_report_id: report_id, transaction_index:) do |rct|
            rct.amount_cents = transaction["available_amount"]
            rct.date_posted = transaction["effective_at"]
            rct.column_transaction = transaction
          end
        end
      end
    end

    def hash_raw_plaid_transactions!
      ::TransactionEngine::HashedTransactionService::RawPlaidTransaction::Import.new(start_date: @start_date).run
    end

    def hash_raw_emburse_transactions!
      ::TransactionEngine::HashedTransactionService::RawEmburseTransaction::Import.new(start_date: @start_date).run
    end

    def hash_raw_stripe_transactions!
      ::TransactionEngine::HashedTransactionService::RawStripeTransaction::Import.new(start_date: @start_date).run
    end

    def hash_raw_csv_transactions!
      ::TransactionEngine::HashedTransactionService::RawCsvTransaction::Import.new.run
    end

    def hash_raw_increase_transactions!
      ::TransactionEngine::HashedTransactionService::RawIncreaseTransaction::Import.new(start_date: @start_date).run
    end

    def canonize_hashed_transactions!
      ::TransactionEngine::CanonicalTransactionService::Import::All.new.run
    end

    def fix_plaid_mistakes!
      BankAccount.syncing_v2.pluck(:id).each do |bank_account_id|
        begin
          ::TransactionEngine::FixMistakes::Plaid.new(bank_account_id:, start_date: @start_date.to_date.iso8601, end_date: nil).run
        rescue => e
          Airbrake.notify(e)
        end
      end
    end

    def fix_memo_mistakes!
      ::TransactionEngine::FixMistakes::Memos.new(start_date: @start_date).run
    end

    private

    def try_to
      yield
    rescue => e
      Airbrake.notify(e)
    end

  end
end
