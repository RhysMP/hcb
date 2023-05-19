# frozen_string_literal: true

module EventService
  class Create
    def initialize(name:, point_of_contact_id:, emails: [], is_signee: true, country: [], category: [], is_public: true, is_indexable: true, approved: false, sponsorship_fee: 0.07, organized_by_hack_clubbers: false, organized_by_teenagers: false, omit_stats: false, can_front_balance: true, demo_mode: false)
      @name = name
      @emails = emails
      @is_signee = is_signee
      @country = country
      @category = category
      @point_of_contact_id = point_of_contact_id
      @is_public = is_public
      @is_indexable = is_indexable
      @approved = approved || false
      @sponsorship_fee = sponsorship_fee ? sponsorship_fee.to_f : 0.07
      @organized_by_hack_clubbers = organized_by_hack_clubbers
      @organized_by_teenagers = organized_by_teenagers
      @omit_stats = omit_stats
      @can_front_balance = can_front_balance
      @demo_mode = demo_mode
    end

    def run
      raise ArgumentError, "name required" unless @name.present?
      raise ArgumentError, "approved must be true or false" unless (@approved == true || @approved == false)
      raise ArgumentError, "sponsorship_fee must be 0 to 0.5" unless (@sponsorship_fee >= 0.0 && @sponsorship_fee <= 0.5)

      ActiveRecord::Base.transaction do
        event = ::Event.create!(attrs)

        # Event aasm_state is already approved by default.
        # event.mark_approved! if @approved

        @emails.each do |email|
          OrganizerPositionInviteService::Create.new(event: event, sender: point_of_contact, user_email: email, initial: true, is_signee: @is_signee).run!
        end
      end
    end

    private

    def attrs
      {
        name: @name,
        start: Date.current,
        end: Date.current,
        address: "N/A",
        country: @country,
        category: @category,
        organized_by_hack_clubbers: @organized_by_hack_clubbers,
        organized_by_teenagers: @organized_by_teenagers,
        omit_stats: @omit_stats,
        is_public: @is_public,
        is_indexable: @is_indexable,
        sponsorship_fee: @sponsorship_fee,
        can_front_balance: @can_front_balance,
        expected_budget: 100.0,
        point_of_contact_id: @point_of_contact_id,
        partner_id: partner.id,
        organization_identifier: organization_identifier,
        demo_mode: @demo_mode
      }
    end

    def point_of_contact
      @point_of_contact ||= ::User.find(@point_of_contact_id)
    end

    def partner
      @partner ||= ::Partner.find_by!(slug: "bank")
    end

    def organization_identifier
      @organization_identifier ||= "bank_#{SecureRandom.hex}"
    end

  end
end
