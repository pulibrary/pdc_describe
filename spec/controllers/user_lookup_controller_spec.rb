# frozen_string_literal: true
require "rails_helper"

RSpec.describe UserLookupController do
  let(:user) { FactoryBot.create(:user) }
  let(:user_other) { FactoryBot.create(:user) }
  let(:user_external) { FactoryBot.create(:external_user) }
  let(:user_external_2) { FactoryBot.create(:external_user_2) }

  it "returns nothing when no user signed in" do
    user # make sure the user is in the database
    get :search, params: { term: user.uid[0..1] }
    expect(response.body).to eq("")
  end

  it "finds the user by partial uid" do
    sign_in user # make sure the user is in the database
    get :search, params: { term: user.uid[0..1] }
    expect(response.body).to eq("[{\"uid\":\"#{user.uid}\",\"name\":\"#{user.full_name}\"}]")
  end

  it "finds the user by partial family name" do
    sign_in user # make sure the user is in the database
    get :search, params: { term: user.family_name[0..1] }
    expect(response.body).to eq("[{\"uid\":\"#{user.uid}\",\"name\":\"#{user.full_name}\"}]")
  end

  it "finds the user by partial given name" do
    sign_in user # make sure the user is in the database
    get :search, params: { term: user.given_name[0..1] }
    expect(response.body).to eq("[{\"uid\":\"#{user.uid}\",\"name\":\"#{user.full_name}\"}]")
  end

  it "orders the results by full name" do
    # instantiated in backwards order to ensure the ordering is working correctly
    user3 = FactoryBot.create(:user, given_name: "Charlie", family_name: "Smith", full_name: "Charlie Smith")
    user2 = FactoryBot.create(:user, given_name: "Bob", family_name: "Smith", full_name: "Bob Smith")
    user1 = FactoryBot.create(:user, given_name: "Alice", family_name: "Smith", full_name: "Alice Smith")
    sign_in user # make sure the user is in the database
    get :search, params: { term: "smith" }
    expect(response.body).to eq("[{\"uid\":\"#{user1.uid}\",\"name\":\"#{user1.full_name}\"},"\
                                "{\"uid\":\"#{user2.uid}\",\"name\":\"#{user2.full_name}\"},"\
                                "{\"uid\":\"#{user3.uid}\",\"name\":\"#{user3.full_name}\"}]")
  end
end
