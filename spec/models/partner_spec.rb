# frozen_string_literal: true

require "rails_helper"

RSpec.describe Partner, type: :model do
  let(:partner) { create(:partner) }

  it "is valid" do
    expect(partner).to be_valid
  end

  it "defaults to external" do
    expect(partner).to be_external
  end

  it "can be searched by api_key" do
    api_key = partner.api_key
    expect(Partner.find_by(api_key: api_key)).to eq(partner)
  end

  context "when slug is reserved" do
    it "fails" do
      partner.slug = "connect"

      expect(partner).to_not be_valid
    end
  end
end
