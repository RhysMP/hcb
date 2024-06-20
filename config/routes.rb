# frozen_string_literal: true

require "sidekiq/web"
require "sidekiq/cron/web"
require "admin_constraint"

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  mount Audits1984::Engine => "/console", constraints: AdminConstraint.new
  mount Sidekiq::Web => "/sidekiq", :constraints => AdminConstraint.new
  mount Flipper::UI.app(Flipper), at: "flipper", as: "flipper", constraints: AdminConstraint.new
  mount Blazer::Engine, at: "blazer", constraints: AdminConstraint.new
  get "/sidekiq", to: "users#auth" # fallback if adminconstraint fails, meaning user is not signed in
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # API documentation
  scope "docs/api" do
    get "v2", to: "docs#v2"
    get "v2/swagger", to: "docs#swagger"

    get "v3", to: "docs#v3"
    get "v3/*path", to: "docs#v3"

    get "/", to: redirect("/docs/api/v3")
  end

  # V3 API
  mount Api::V3 => "/"

  root to: "static_pages#index"
  get "stats", to: "stats#stats"
  get "stats_custom_duration", to: "stats#stats_custom_duration"
  get "stats/admin_receipt_stats", to: "stats#admin_receipt_stats"
  get "project_stats", to: "stats#project_stats"
  get "bookkeeping", to: "admin#bookkeeping"
  get "stripe_charge_lookup", to: "static_pages#stripe_charge_lookup"

  post "feedback", to: "static_pages#feedback"

  resources :receipts, only: [:create, :destroy] do
    collection do
      post "link"
      get "link_modal"
    end
  end

  scope :my do
    get "/", to: redirect("/"), as: :my
    get "settings", to: "users#edit", as: :my_settings
    get "settings/address", to: "users#edit_address"
    get "settings/payouts", to: "users#edit_payout"
    get "settings/previews", to: "users#edit_featurepreviews"
    get "settings/security", to: "users#edit_security"
    get "settings/admin", to: "users#edit_admin"
    get "inbox", to: "static_pages#my_inbox", as: :my_inbox
    get "receipt_bin/suggested_pairings", to: "static_pages#suggested_pairings", as: :suggested_pairings
    get "reimbursements", to: "static_pages#my_reimbursements", as: :my_reimbursements
    get "activities", to: "static_pages#my_activities", as: :my_activities
    get "draft_reimbursements_icon", to: "static_pages#my_draft_reimbursements_icon", as: :my_draft_reimbursements_icon
    post "receipts/upload", to: "static_pages#receipt", as: :my_receipts_upload
    get "missing_receipts", to: "static_pages#my_missing_receipts_list", as: :my_missing_receipts_list
    get "missing_receipts_icon", to: "static_pages#my_missing_receipts_icon", as: :my_missing_receipts_icon
    get "receipts", to: redirect("/my/inbox")

    post "receipt_report", to: "users#receipt_report", as: :trigger_receipt_report

    get "cards", to: "static_pages#my_cards", as: :my_cards
    get "cards/shipping", to: "stripe_cards#shipping", as: :my_cards_shipping
  end

  resources :mailbox_addresses, only: [:create, :show] do
    member do
      post "activate"
    end
  end

  resources :suggested_pairings, only: [] do
    member do
      post "ignore"
      post "accept"
    end
  end

  post "receiptable/:receiptable_type/:receiptable_id/mark_no_or_lost", to: "receiptables#mark_no_or_lost", as: :receiptable_mark_no_or_lost

  # Feature-flags
  post "enable_feature", to: "features#enable_feature"
  post "disable_feature", to: "features#disable_feature"

  resources :users, only: [:edit, :update] do
    collection do
      get "auth", to: "users#auth"
      post "auth", to: "users#auth_submit"
      get "auth/login_preference", to: "users#choose_login_preference", as: :choose_login_preference
      post "auth/login_preference", to: "users#set_login_preference", as: :set_login_preference
      post "webauthn", to: "users#webauthn_auth"
      get "webauthn/auth_options", to: "users#webauthn_options"
      post "login_code", to: "users#login_code"
      post "exchange_login_code", to: "users#exchange_login_code"

      # TOTP
      get "totp"
      post "totp"
      post "totp_auth"

      # SMS Auth
      post "start_sms_auth_verification", to: "users#start_sms_auth_verification"
      post "complete_sms_auth_verification", to: "users#complete_sms_auth_verification"
      post "toggle_sms_auth", to: "users#toggle_sms_auth"

      # Logout
      delete "logout", to: "users#logout"
      delete "logout_all", to: "users#logout_all"
      delete "logout_session", to: "users#logout_session"
      delete "revoke/:id", to: "users#revoke_oauth_application", as: "revoke_oauth_application"

      # sometimes users refresh the login code page and get 404'd
      get "exchange_login_code", to: redirect("/users/auth", status: 301)
      get "login_code", to: redirect("/users/auth", status: 301)

      # For compatibility with the previous WebAuthn login flow
      get "webauthn", to: redirect("/users/auth")
    end
    member do
      get "address", to: "users#edit_address"
      get "payouts", to: "users#edit_payout"
      get "previews", to: "users#edit_featurepreviews"
      get "security", to: "users#edit_security"
      get "admin", to: "users#edit_admin"

      post "impersonate"
      post "unimpersonate"
    end
    post "delete_profile_picture", to: "users#delete_profile_picture"
    post "enable_totp"
    post "disable_totp"
    patch "stripe_cardholder_profile", to: "stripe_cardholders#update_profile"

    resources :webauthn_credentials, only: [:create, :destroy] do
      collection do
        get "register_options"
      end
    end
  end
  scope module: :users do
    resources "wrapped", only: :index do
      collection do
        get "data"
      end
    end
    resources :email_updates, only: [] do
      collection do
        get "verify"
        get "authorize", to: "email_updates#authorize_change"
      end
    end
  end

  resources :admin, only: [] do
    collection do
      get "bank_accounts", to: "admin#bank_accounts"
      get "hcb_codes", to: "admin#hcb_codes"
      get "bank_fees", to: "admin#bank_fees"
      get "users", to: "admin#users"
      get "partners", to: "admin#partners"
      get "partner/:id", to: "admin#partner", as: "partner"
      post "partner/:id", to: "admin#partner_edit"
      get "partnered_signups", to: "admin#partnered_signups"
      post "partnered_signups/:id/sign", to: "admin#partnered_signup_sign_document", as: "partnered_signup_sign_document"
      get "raw_transactions", to: "admin#raw_transactions"
      get "raw_transaction_new", to: "admin#raw_transaction_new"
      post "raw_transaction_create", to: "admin#raw_transaction_create"
      get "ledger", to: "admin#ledger"
      get "stripe_cards", to: "admin#stripe_cards"
      get "pending_ledger", to: "admin#pending_ledger"
      get "ach", to: "admin#ach"
      get "reimbursements", to: "admin#reimbursements"
      get "checks", to: "admin#checks"
      get "increase_checks", to: "admin#increase_checks"
      get "paypal_transfers", to: "admin#paypal_transfers"
      get "partner_organizations", to: "admin#partner_organizations"
      get "events", to: "admin#events"
      get "event_new", to: "admin#event_new"
      post "event_create", to: "admin#event_create"
      get "donations", to: "admin#donations"
      get "recurring_donations", to: "admin#recurring_donations"
      get "partner_donations", to: "admin#partner_donations"
      get "disbursements", to: "admin#disbursements"
      get "disbursement_new", to: "admin#disbursement_new"
      get "invoices", to: "admin#invoices"
      get "sponsors", to: "admin#sponsors"
      get "google_workspaces", to: "admin#google_workspaces"
      post "google_workspaces_verify_all", to: "admin#google_workspaces_verify_all"
      get "balances", to: "admin#balances"
      get "grants", to: "admin#grants"
      get "check_deposits", to: "admin#check_deposits"
      get "column_statements", to: "admin#column_statements"
      get "hq_receipts", to: "admin#hq_receipts"
      get "account_numbers", to: "admin#account_numbers"

      resources :grants, only: [] do
        post "approve"
        post "additional_info_needed"
        post "reject"
        post "mark_fulfilled"
      end
    end

    member do
      get "transaction", to: "admin#transaction"
      get "event_balance", to: "admin#event_balance"
      get "event_raised", to: "admin#event_raised"
      get "event_process", to: "admin#event_process"
      put "event_toggle_approved", to: "admin#event_toggle_approved"
      put "event_reject", to: "admin#event_reject"
      get "ach_start_approval", to: "admin#ach_start_approval"
      post "ach_approve", to: "admin#ach_approve"
      post "ach_reject", to: "admin#ach_reject"
      get "disbursement_process", to: "admin#disbursement_process"
      post "disbursement_approve", to: "admin#disbursement_approve"
      post "disbursement_reject", to: "admin#disbursement_reject"
      get "increase_check_process", to: "admin#increase_check_process"
      get "paypal_transfer_process", to: "admin#paypal_transfer_process"
      get "google_workspace_process", to: "admin#google_workspace_process"
      post "google_workspace_approve", to: "admin#google_workspace_approve"
      post "google_workspace_verify", to: "admin#google_workspace_verify"
      post "google_workspace_update", to: "admin#google_workspace_update"
      get "invoice_process", to: "admin#invoice_process"
      post "invoice_mark_paid", to: "admin#invoice_mark_paid"
      get "grant_process", to: "admin#grant_process"

      post "partnered_signups_accept", to: "admin#partnered_signups_accept"
      post "partnered_signups_reject", to: "admin#partnered_signups_reject"
    end
  end

  namespace :admin do
    namespace :ledger_audits do
      resources :tasks, only: [:index, :show, :create] do
        post :reviewed
        post :flagged
      end
    end
    resources :ledger_audits, only: [:index, :show]
  end

  post "set_event", to: "admin#set_event_multiple_transactions", as: :set_event_multiple_transactions
  post "set_event/:id", to: "admin#set_event", as: :set_event
  post "set_paypal_transfer/:id", to: "admin#set_paypal_transfer", as: :set_paypal_transfer

  resources :organizer_position_invites, only: [:show], path: "invites" do
    post "accept"
    post "reject"
    post "cancel"
    member do
      post "toggle_signee_status"
      post "change_position_role"
    end
  end

  resources :organizer_positions, only: [:destroy], as: "organizers" do
    member do
      post "set_index"
      post "mark_visited"
      post "toggle_signee_status"
      post "change_position_role"
    end

    resources :organizer_position_deletion_requests, only: [:new], as: "remove"
  end

  resources :organizer_position_deletion_requests, only: [:index, :show, :create] do
    post "close"
    post "open"

    resources :comments
  end

  resources :g_suite_accounts, only: [:index, :create, :update, :edit, :destroy], path: "g_suite_accounts" do
    put "reset_password"
    put "toggle_suspension"
    get "verify", to: "g_suite_account#verify"
    post "reject"
  end

  resources :g_suites, except: [:new, :create, :edit, :update] do
    resources :g_suite_accounts, only: [:create]

    resources :comments
  end

  resources :sponsors

  resources :invoices, only: [:show] do
    post "manually_mark_as_paid"
    post "archive"
    post "unarchive"
    post "void"
    get "hosted"
    get "pdf"
    member do
      post "refund"
    end
    resources :comments
  end

  resources :stripe_cardholders, only: [:new, :create, :update]

  namespace :stripe_cards do
    resource :activation, only: [:new, :create], controller: :activation
  end
  resources :stripe_cards, only: %i[edit update create index show] do
    member do
      post "freeze"
      post "defrost"
    end
  end
  resources :emburse_cards, except: %i[new create]

  resources :checks, only: [:show] do
    resources :comments
  end

  resources :increase_checks, only: [] do
    member do
      post "approve"
      post "reject"
    end
  end

  resources :paypal_transfers, only: [] do
    member do
      post "approve"
      post "reject"
    end
  end

  resources :ach_transfers, only: [:show] do
    member do
      post "cancel"
      post "toggle_speed"
    end
    collection do
      post "validate_routing_number"
    end
    get "confirmation", to: "ach_transfers#transfer_confirmation_letter"
    resources :comments
  end

  resources :disbursements, only: [:index, :new, :create, :show, :edit, :update] do
    post "mark_fulfilled"
    post "reject"
    get "confirmation", to: "disbursements#transfer_confirmation_letter"
  end

  resources :comments, only: [:edit, :update]

  resources :documents, except: [:index] do
    collection do
      get "", to: "documents#common_index", as: :common
    end
    get "download"
    post "toggle", to: "documents#toggle_archive"
  end

  resources :bank_accounts, only: [:new, :create, :update, :show, :index] do
    get "reauthenticate"
  end

  resources :hcb_codes, path: "/hcb", only: [:show, :edit, :update] do
    member do
      post "comment"
      get "attach_receipt"
      get "memo_frame"
      get "dispute"
      get "breakdown"
      post "invoice_as_personal_transaction"
      post "pin"
      post "toggle_tag/:tag_id", to: "hcb_codes#toggle_tag", as: :toggle_tag
      post "send_receipt_sms", to: "hcb_codes#send_receipt_sms", as: :send_sms_receipt
    end

    resources :comments
  end

  resources :canonical_pending_transactions, only: [:show, :edit] do
    member do
      post "set_custom_memo"
    end
  end

  resources :canonical_transactions, only: [:show, :edit] do
    member do
      post "waive_fee"
      post "unwaive_fee"
      post "mark_bank_fee"
      post "set_custom_memo"
    end

    resources :comments
  end

  resources :exports do
    collection do
      get "collect_email", to: "exports#collect_email", as: "collect_email"
      get ":event", to: "exports#transactions", as: "transactions"
    end
  end

  resources :transactions, only: [:index, :show, :edit, :update] do
    resources :comments
  end
  namespace :reimbursement do
    resources :reports, only: [:show, :create, :edit, :update, :destroy] do
      post "request_reimbursement"
      post "admin_approve"
      post "approve_all_expenses"
      post "request_changes"
      post "reject"
      post "submit"
      post "draft"
      collection do
        post "quick_expense"
        get "/:event_name/finished", to: "reports#finished", as: "finished"
      end
    end

    get "start/:event_name", to: "reports#start", as: "start_reimbursement_report"

    resources :expenses, only: [:create, :edit, :update, :destroy] do
      post "approve"
      post "unapprove"
    end
  end

  resources :reimbursement_reports, path: "reimbursements/reports" do
    resources :comments
  end

  get "brand_guidelines", to: redirect("branding")
  get "branding", to: "static_pages#branding"
  get "faq", to: "static_pages#faq"
  get "roles", to: "static_pages#roles"
  get "audit", to: "admin#audit"

  resources :central, only: [:index] do
    collection do
      get "ledger"
    end
  end

  resources :emburse_card_requests, path: "emburse_card_requests", except: [:new, :create] do
    collection do
      get "export"
    end
    post "reject"
    post "cancel"

    resources :comments
  end

  resources :emburse_transfers, except: [:new, :create] do
    collection do
      get "export"
    end
    post "accept"
    post "reject"
    post "cancel"
    resources :comments
  end

  resources :emburse_transactions, only: [:index, :edit, :update, :show] do
    resources :comments
  end

  resources :donations, only: [:show] do
    collection do
      get "start/:event_name", to: "donations#start_donation", as: "start_donation"
      post "start/:event_name", to: "donations#make_donation", as: "make_donation"
      get "qr/:event_name.png", to: "donations#qr_code", as: "qr_code"
      get ":event_name/:donation", to: "donations#finish_donation", as: "finish_donation"
      get ":event_name/:donation/finished", to: "donations#finished", as: "finished_donation"
      get "export"
      get "export_donors"
    end

    member do
      post "refund", to: "donations#refund"
    end

    resources :comments
  end

  resources :partner_donations, only: [:show] do
    collection do
      get "export"
    end
  end

  use_doorkeeper scope: "api/v4/oauth" do
    skip_controllers :authorized_applications
  end

  namespace :api do
    get "v2/login", to: "v2#login"

    post "v2/donations/new", to: "v2#donations_new"

    get "v2/organizations", to: "v2#organizations"
    get "v2/organization/:public_id", to: "v2#organization", as: :v2_organization
    post "v2/organization/:public_id/generate_login_url", to: "v2#generate_login_url", as: :v2_generate_login_url

    post "v2/partnered_signups/new", to: "v2#partnered_signups_new"
    get "v2/partnered_signups", to: "v2#partnered_signups"
    get "v2/partnered_signup/:public_id", to: "v2#partnered_signup", as: :v2_partnered_signup

    namespace :v4 do
      defaults format: :json do
        resource :user do
          resources :events, path: "organizations", only: [:index]
          resources :stripe_cards, path: "cards", only: [:index]
          resources :invitations, only: [:index, :show] do
            member do
              post "accept"
              post "reject"
            end
          end

          get "transactions/missing_receipt", to: "transactions#missing_receipt"
          get :available_icons
        end

        resources :events, path: "organizations", only: [:show] do
          resources :stripe_cards, path: "cards", only: [:index]
          resources :transactions, only: [:show, :update] do
            resources :receipts, only: [:create, :index]
            resources :comments, only: [:index]

            member do
              get "memo_suggestions"
            end
          end

          resources :disbursements, path: "transfers", only: [:create]

          member do
            get "transactions"
          end
        end

        resources :transactions, only: [:show]

        resources :stripe_cards, path: "cards", only: [:show, :update] do
          member do
            get "transactions"
            get "ephemeral_keys"
          end
        end

        match "*path" => "application#not_found", via: [:get, :post]
      end
    end
  end

  get "partnered_signups/:public_id", to: "partnered_signups#edit", as: :edit_partnered_signups
  patch "partnered_signups/:public_id", to: "partnered_signups#update", as: :update_partnered_signups

  post "api/v1/users/find", to: "api#user_find"
  post "api/v1/events/create_demo", to: "api#create_demo_event"
  get "api/current_user", to: "api#the_current_user"

  post "twilio/webhook", to: "twilio#webhook"
  post "stripe/webhook", to: "stripe#webhook"
  post "increase/webhook", to: "increase#webhook"
  post "webhooks/column", to: "column/webhooks#webhook"

  get "negative_events", to: "admin#negative_events"

  get "admin_task_size", to: "admin#task_size"
  get "admin_search", to: redirect("/admin/users")
  post "admin_search", to: redirect("/admin/users")

  resources :tours, only: [] do
    member do
      post "mark_complete"
      post "set_step"
    end
  end

  resources :recurring_donations, only: [:show, :edit, :update], path: "recurring" do
    member do
      post "cancel"
    end
  end

  resources :card_grants, only: [:show], path: "grants" do
    member do
      post "activate"
      get "spending"
    end
  end

  resources :grants, only: [:show], path: "grants_v2" do
    member do
      post "activate"
    end
  end

  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all

  Rack::Utils::HTTP_STATUS_CODES.keys.select { |c| c >= 400 }.each do |code|
    match "/#{code}", to: "errors#error", via: :all, code:
  end

  get "/search" => "search#index"

  get "/events" => "events#index"
  get "/event_by_airtable_id/:airtable_id" => "events#by_airtable_id"
  resources :events, except: [:new, :create], path_names: { edit: "settings" }, path: "/" do
    get "edit", to: redirect("/%{event_id}/settings")
    get "breakdown"
    put "toggle_hidden"
    post "claim_point_of_contact"

    post "remove_header_image"
    post "remove_background_image"
    post "remove_logo"

    get "team"
    get "google_workspace", to: "events#g_suite_overview", as: :g_suite_overview
    post "g_suite_create"
    put "g_suite_verify"
    get "emburse_cards", to: "events#emburse_card_overview", as: :emburse_cards_overview
    get "cards", to: "events#card_overview", as: :cards_overview
    get "cards/new", to: "stripe_cards#new"
    get "stripe_cards/shipping", to: "stripe_cards#shipping", as: :stripe_cards_shipping

    get "transfers/new", to: "events#new_transfer"

    get "async_balance"
    get "reimbursements_pending_review_icon"

    # (@eilla1) these pages are for the wip resources page and will be moved later
    get "connect_gofundme"
    get "sell_merch"

    get "documentation"
    get "transfers"
    get "statements"
    get "promotions"
    get "expensify"
    get "reimbursements"
    get "donations", to: "events#donation_overview", as: :donation_overview
    get "partner_donations", to: "events#partner_donation_overview", as: :partner_donation_overviews
    get "activation_flow", to: "events#activation_flow", as: :activation_flow
    post "activate", to: "events#activate", as: :activate
    post "demo_mode_request_meeting"
    post "finish_signee_backfill"
    resources :disbursements, only: [:new, :create]
    resources :increase_checks, only: [:new, :create], path: "checks"
    resources :paypal_transfers, only: [:new, :create]
    resources :ach_transfers, only: [:new, :create]
    resources :organizer_position_invites,
              only: [:new, :create],
              path: "invites"
    resources :g_suites, only: [:new, :create, :edit, :update]
    resources :documents, only: [:index]
    get "fiscal_sponsorship_letter", to: "documents#fiscal_sponsorship_letter"
    resources :invoices, only: [:new, :create, :index]
    resources :tags, only: [:create, :destroy]
    resources :event_tags, only: [:create, :destroy]
    resources :comments

    resources :recurring_donations, only: [:create], path: "recurring" do
      member do
        get "pay"
        get "finished"
      end
    end

    resources :check_deposits, only: [:index, :create], path: "check-deposits"

    resources :card_grants, only: [:new, :create], path: "card-grants" do
      member do
        post "cancel"
      end
    end

    resources :grants, only: [:index, :new, :create]

    resource :column_account_number, controller: "column/account_number", only: [:create, :update], path: "account-number"

    resources :organizer_positions, path: "team", only: [] do
      resources :organizer_position_deletion_requests, path: "removal-requests", as: "remove", only: [:new]

      scope module: "organizer_position" do
        namespace :spending do
          resources :controls do
            resources :allowances, only: [:new, :create], controller: "control/allowances"
          end
        end
      end
    end

    resources :payment_recipients, only: [:destroy]


    member do
      post "test_ach_payment"
      get "account-number", to: "events#account_number"
      post "toggle_event_tag/:event_tag_id", to: "events#toggle_event_tag", as: :toggle_event_tag
      get "audit_log"
      post "validate_slug"
      get "termination"
    end

    get "balance_by_date"
  end

  # rewrite old event urls to the new ones not prefixed by /events/
  get "/events/*path", to: redirect("/%{path}", status: 302)

  # Beware: Routes after "resources :events" might be overwritten by a
  # similarly named event
end
