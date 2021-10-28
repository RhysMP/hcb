# frozen_string_literal: true

class Partner < ApplicationRecord
  EXCLUDED_SLUGS = %w(connect api donations donation connects organization organizations)

  attribute :api_key, :string, default: -> { new_api_key }

  has_many :events
  has_many :partner_donations, through: :events

  validates :slug, exclusion: { in: EXCLUDED_SLUGS }, uniqueness: true
  validates :api_key, presence: true, uniqueness: true

  encrypts :stripe_api_key

  def regenerate_api_key!
    self.api_key = new_api_key
    self.save!
  end

  private

  def new_api_key
    "hcbk_#{SecureRandom.hex(32)}"
  end

  def self.new_api_key
    self.new.send(:new_api_key)
  end
end
