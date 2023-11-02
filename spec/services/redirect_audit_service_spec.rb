# frozen_string_literal: true
require "rails_helper"

RSpec.describe RedirectAuditService do
  let(:service) { RedirectAuditService.new }

  before do
    5.times do
      FactoryBot.create(:migrated_and_approved_work)
    end
    3.times do
      FactoryBot.create(:approved_work)
    end
  end

  # It is the migrated and approved objects whose redirects we need to audit
  it "gets all migrated and approved objects" do
    expect(service.redirected_works.count).to eq(5)
  end

  describe "an ark that was correctly redirected" do
    let(:redirected_ark) { FactoryBot.create(:ezid_with_redirection) }
    it "has princeton data commons url in the ark target" do
      expect(redirected_ark.target).to match(/datacommons\.princeton\.edu/)
      expect(service.ark_redirected?(redirected_ark)).to eq(true)
    end
  end

  describe "an ark that was not correctly redirected" do
    let(:unredirected_ark) { FactoryBot.create(:ezid_without_redirection) }
    it "does not have the princeton data commons url in the ark target" do
      expect(unredirected_ark.target).not_to match(/datacommons\.princeton\.edu/)
      expect(service.ark_redirected?(unredirected_ark)).to eq(false)
    end
  end
end
