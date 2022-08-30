# frozen_string_literal: true
require "rails_helper"

RSpec.describe UserCollection, type: :model do
  let(:collection) { FactoryBot.create :collection }
  let(:user) { FactoryBot.create :user }
  describe "#migrate" do
    it "migrates admin role" do
      UserCollection.add_admin(user.id, collection.id)
      user_collectin = UserCollection.last
      user_collectin.migrate
      expect(user.has_role?(:collection_admin, collection)).to be_truthy
    end

    it "migrates submitter role" do
      UserCollection.add_submitter(user.id, collection.id)
      user_collectin = UserCollection.last
      user_collectin.migrate
      expect(user.has_role?(:submitter, collection)).to be_truthy
    end
  end
end
