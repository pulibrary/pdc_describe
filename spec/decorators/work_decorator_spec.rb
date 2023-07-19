# frozen_string_literal: true
require "rails_helper"

describe WorkDecorator, type: :model do
  subject(:decorator) { WorkDecorator.new(work, user) }
  let(:user) { FactoryBot.create(:user) }
  let(:work) { FactoryBot.create(:draft_work) }

  it "delegate methods" do
    expect(decorator.group).to eq(work.group)
    expect(decorator.resource).to eq(work.resource)
    expect(decorator.migrated).to be_falsey
    work.resource.migrated = true
    expect(decorator.migrated).to be_truthy
  end

  describe "#show_complete_button?" do
    let(:group) { Group.default }
    let(:user) { FactoryBot.create(:user) }
    let(:depositor) { FactoryBot.create(:user) }
    let(:work) { FactoryBot.create(:draft_work, created_by_user_id: depositor.id, group: user.default_group) }

    before do
      Group.create_defaults
      user
    end

    context "when the work is not in the draft state" do
      let(:work) { FactoryBot.create(:approved_work, created_by_user_id: depositor.id, group: user.default_group) }

      it "does not allow the current user to mark the item complete" do
        expect(decorator.group).to eq(work.group)
        expect(decorator.show_complete_button?).to be false
      end
    end

    context "when the work belongs to a group" do
      context "and the current user is an admin for the group" do
        let(:user) { FactoryBot.create(:user, groups_to_admin: [group]) }

        it "allows the current user to mark the item complete" do
          expect(decorator.group).to eq(work.group)
          expect(decorator.show_complete_button?).to be true
        end
      end

      it "does not allow the current user to mark the item complete" do
        expect(decorator.group).to eq(work.group)
        expect(decorator.show_complete_button?).to be false
      end
    end
  end
end
