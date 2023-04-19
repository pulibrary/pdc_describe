# frozen_string_literal: true
require "rails_helper"

describe CollectionOption, type: :model do
  describe ".option_type_labels" do
    it "enumerates the labels for each option type" do
      expect(described_class.option_type_labels).to include(email_messages: "E-mail messages for Collection notifications")
    end
  end

  describe ".find_option_type_label" do
    subject(:collection_option) { described_class.create(option_type: described_class::EMAIL_MESSAGES, group: collection, user: user) }
    let(:collection) { FactoryBot.create(:group) }
    let(:user) { FactoryBot.create(:user) }
    let(:label) do
      described_class.find_option_type_label(collection_option.option_type)
    end

    it "resolves option types to a human-readable label" do
      expect(label).to eq("E-mail messages for Collection notifications")
    end
  end

  describe "#option_type_label" do
    subject(:collection_option) { described_class.create(option_type: described_class::EMAIL_MESSAGES, group: collection, user: user) }
    let(:collection) { FactoryBot.create(:group) }
    let(:user) { FactoryBot.create(:user) }
    let(:label) { collection_option.option_type_label }

    it "resolves option types to a human-readable label" do
      expect(label).to eq("E-mail messages for Collection notifications")
    end
  end
end
