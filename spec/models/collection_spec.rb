# frozen_string_literal: true
require "rails_helper"

RSpec.describe Collection, type: :model do
  it "creates default collections only when needed" do
    described_class.delete_all
    expect(described_class.count).to be 0

    described_class.create_defaults
    default_count = described_class.count
    expect(default_count).to be > 0

    expect(Collection.where(code: "PPPL").count).to be 1
    expect(Collection.where(code: "RD").count).to be 1

    described_class.create_defaults
    expect(described_class.count).to be default_count
  end

  it "creates defaults when not defined" do
    described_class.delete_all
    expect(described_class.count).to be 0
    expect(Collection.default).to_not be nil

    described_class.delete_all
    expect(described_class.count).to be 0
    expect(Collection.default_for_department("41000")).to_not be nil
  end

  describe ".default_for_department" do
    subject(:collection) { described_class.default_for_department(department_number) }

    context "when the department number is less than 31000" do
      let(:department_number) { "30000" }
      it "provides the default collection" do
        expect(collection).to be_a(Collection)
        expect(collection.code).to eq("RD")
      end
    end

    context "when the department number is unexpected" do
      let(:department_number) { "foobar" }
      it "provides the default collection" do
        expect(collection).to be_a(Collection)
        expect(collection.code).to eq("RD")
      end
    end

    context "when the department number is PPPL" do
      let(:department_number) { "31000" }
      it "provides the default collection" do
        expect(collection).to be_a(Collection)
        expect(collection.code).to eq("PPPL")
      end
    end
  end

  describe "#disable_messages_for" do
    let(:user) { FactoryBot.create(:user) }
    let(:collection) { described_class.create(title: "test") }

    context "when the user is a super admin" do
      let(:user) { User.new_super_admin("test-admin") }

      it "disables email messages for notifications for a User" do
        # Initially messages are disabled for the user
        state = collection.messages_enabled_for?(user: user)
        expect(state).to be false

        collection.enable_messages_for(user: user)
        collection.save!
        collection.reload

        # After enabling messages for the user, that they are enabled is verified
        enabled_state = collection.messages_enabled_for?(user: user)
        expect(enabled_state).to be true

        collection.disable_messages_for(user: user)
        collection.save!
        collection.reload

        # After disabling messages for the user, that they are disabled is verified
        disabled_state = collection.messages_enabled_for?(user: user)
        expect(disabled_state).to be false
      end
    end

    context "when the user is an administrator for a Collection" do
      before do
        user.add_role(:collection_admin, collection)
        user.save!
      end

      it "disables email messages for notifications for a User" do
        # Initially messages are disabled for the user
        state = collection.messages_enabled_for?(user: user)
        expect(state).to be false

        collection.enable_messages_for(user: user)
        collection.save!
        collection.reload

        # After enabling messages for the user, that they are enabled is verified
        enabled_state = collection.messages_enabled_for?(user: user)
        expect(enabled_state).to be true

        collection.disable_messages_for(user: user)
        collection.save!
        collection.reload

        # After disabling messages for the user, that they are disabled is verified
        disabled_state = collection.messages_enabled_for?(user: user)
        expect(disabled_state).to be false
      end
    end

    it "raises an ArgumentError" do
      state = collection.messages_enabled_for?(user: user)
      expect(state).to be false

      expect { collection.disable_messages_for(user: user) }.to raise_error(ArgumentError, "User #{user.uid} is not an administrator for this collection #{collection.title}")
    end
  end
end
