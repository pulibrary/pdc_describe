# frozen_string_literal: true
require "rails_helper"

RSpec.describe Group, type: :model do
  it "creates default groups only when needed" do
    described_class.delete_all
    expect(described_class.count).to be 0

    described_class.create_defaults
    default_count = described_class.count
    expect(default_count).to be > 0

    expect(described_class.where(code: "PPPL").count).to be 1
    expect(described_class.where(code: "RD").count).to be 1

    described_class.create_defaults
    expect(described_class.count).to be default_count
  end

  it "creates defaults when not defined" do
    described_class.delete_all
    expect(described_class.count).to be 0
    expect(described_class.default).to_not be nil

    described_class.delete_all
    expect(described_class.count).to be 0
    expect(described_class.default_for_department("41000")).to_not be nil
  end

  it "sorts alphabetically communities and subcommunities" do
    described_class.create_defaults
    group_rd = described_class.where(code: "RD").first
    expect(group_rd.communities.first).to eq "Architecture"
    expect(group_rd.communities.last).to eq "Sociology"

    group_pppl = described_class.where(code: "PPPL").first
    expect(group_pppl.subcommunities.first).to eq "Advanced Projects"
    expect(group_pppl.subcommunities.last).to eq "Tokamak Experimental Sciences"
  end

  describe ".default_for_department" do
    subject(:group) { described_class.default_for_department(department_number) }

    context "when the department number is less than 31000" do
      let(:department_number) { "30000" }
      it "provides the default group" do
        expect(group).to be_a(described_class)
        expect(group.code).to eq("RD")
      end
    end

    context "when the department number is unexpected" do
      let(:department_number) { "foobar" }
      it "provides the default group" do
        expect(group).to be_a(described_class)
        expect(group.code).to eq("RD")
      end
    end

    context "when the department number is PPPL" do
      let(:department_number) { "31000" }
      it "provides the default group" do
        expect(group).to be_a(described_class)
        expect(group.code).to eq("PPPL")
      end
    end

    context "when the department number is in the middle of PPPL" do
      let(:department_number) { "31012" }
      it "provides the default group" do
        expect(group).to be_a(described_class)
        expect(group.code).to eq("PPPL")
      end
    end

    context "when the department number is at the other end of PPPL" do
      let(:department_number) { "31027" }
      it "provides the default group" do
        expect(group).to be_a(described_class)
        expect(group.code).to eq("PPPL")
      end
    end
  end

  describe "#disable_messages_for" do
    let(:user) { FactoryBot.create(:user) }
    let(:group) { described_class.create(title: "test") }

    context "when the user is a super admin" do
      let(:user) { User.new_super_admin("test-admin") }

      it "disables email messages for notifications for a User" do
        # Initially messages are enabled for the user
        state = group.messages_enabled_for?(user:)
        expect(state).to be true

        # After disabling messages for the user, that they are disabled is verified
        group.disable_messages_for(user:)
        group.save!
        group.reload
        disabled_state = group.messages_enabled_for?(user:)
        expect(disabled_state).to be false
      end
    end

    context "when the user is an administrator for a group" do
      before do
        user.add_role(:group_admin, group)
        user.save!
      end

      it "disables email messages for notifications for a User" do
        # Initially messages are enabled for the user
        state = group.messages_enabled_for?(user:)
        expect(state).to be true

        group.disable_messages_for(user:)
        group.save!
        group.reload

        # After disabling messages for the user, that they are disabled is verified
        disabled_state = group.messages_enabled_for?(user:)
        expect(disabled_state).to be false
      end
    end

    it "raises an ArgumentError" do
      state = group.messages_enabled_for?(user:)
      expect(state).to be true

      expect { group.disable_messages_for(user:) }.to raise_error(ArgumentError, "User #{user.uid} is not an administrator or submitter for this group #{group.title}")
    end
  end

  describe "#default_user" do
    it "creates a new user with the current group as the deafult" do
      user = Group.plasma_laboratory.default_user("abc123")
      expect(user.default_group).to eq(Group.plasma_laboratory)
    end

    it "allows an existing user to keep it's original group" do
      user = User.new_for_uid("abc123")
      Group.plasma_laboratory.default_user("abc123")
      expect(user.reload.default_group).to eq(Group.research_data)
    end

    context "when an error is encountered while persisting the user model" do
      let(:user) { FactoryBot.build(:user) }
      let(:uid) { "abc234" }
      let(:default_group_id) { Group.plasma_laboratory.id }

      before do
        user
        allow(User).to receive(:new).with(uid:, default_group_id:).and_raise(ActiveRecord::RecordNotUnique)
        allow(User).to receive(:new).with(uid:).and_return(user)
      end

      it "attempts to create a new user mode without initially setting the default group ID" do
        persisted = Group.plasma_laboratory.default_user("abc234")

        expect(persisted.default_group_id).to eq(Group.plasma_laboratory.id)
      end
    end
  end

  describe "#delete_permission" do
    it "deletes only the admin permissions" do
      moderator = FactoryBot.create(:pppl_moderator)
      other_user = FactoryBot.create(:user)
      Group.plasma_laboratory.add_submitter(moderator, other_user)
      Group.plasma_laboratory.add_administrator(moderator, other_user)
      expect(other_user.can_submit?(Group.plasma_laboratory)).to be_truthy
      expect(other_user.can_admin?(Group.plasma_laboratory)).to be_truthy

      Group.plasma_laboratory.delete_permission(moderator, other_user, "group_admin")
      expect(other_user.can_submit?(Group.plasma_laboratory)).to be_truthy
      expect(other_user.can_admin?(Group.plasma_laboratory)).to be_falsey
    end

    it "deletes only the submitter permissions" do
      moderator = FactoryBot.create(:pppl_moderator)
      other_user = FactoryBot.create(:user)
      Group.plasma_laboratory.add_submitter(moderator, other_user)
      Group.plasma_laboratory.add_administrator(moderator, other_user)
      expect(other_user.can_submit?(Group.plasma_laboratory)).to be_truthy
      expect(other_user.can_admin?(Group.plasma_laboratory)).to be_truthy

      Group.plasma_laboratory.delete_permission(moderator, other_user, "submitter")
      expect(other_user.can_submit?(Group.plasma_laboratory)).to be_falsey
      expect(other_user.can_admin?(Group.plasma_laboratory)).to be_truthy
    end
  end
end
