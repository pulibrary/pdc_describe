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
    expect(service.migrated_objects.count).to eq(5)
  end
end
