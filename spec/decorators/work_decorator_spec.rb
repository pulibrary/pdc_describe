# frozen_string_literal: true
require "rails_helper"

describe WorkDecorator, type: :model do
  subject(:decorator) { WorkDecorator.new(work, user) }
  let(:user) { FactoryBot.create(:user) }
  let(:work) { FactoryBot.create(:draft_work) }

  it "delgate methods" do
    expect(decorator.group).to eq(work.group)
    expect(decorator.resource).to eq(work.resource)
    expect(decorator.migrated).to be_falsey
    work.resource.migrated = true
    expect(decorator.migrated).to be_truthy
  end
end
