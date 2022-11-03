# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  before { Collection.create_defaults }

  let(:access_token) { OmniAuth::AuthHash.new(provider: "cas", uid: "who", extra: { mail: "who@princeton.edu" }) }
  let(:access_token_pppl) { OmniAuth::AuthHash.new(provider: "cas", uid: "who", extra: { mail: "who@princeton.edu", departmentnumber: "31000" }) }
  let(:access_token_super_admin) { OmniAuth::AuthHash.new(provider: "cas", uid: "fake1", extra: { mail: "fake@princeton.edu" }) }

  let(:access_token_full_extras) do
    OmniAuth::AuthHash.new(provider: "cas", uid: "test123",
                           extra: OmniAuth::AuthHash.new(mail: "who@princeton.edu", user: "test123", authnContextClass: "mfa-duo",
                                                         campusid: "who.areyou", puresidentdepartmentnumber: "41999",
                                                         title: "The Developer, Library - Information Technology.", uid: "test123",
                                                         universityid: "999999999", displayname: "Areyou, Who", pudisplayname: "Areyou, Who",
                                                         edupersonaffiliation: "staff", givenname: "Who",
                                                         sn: "Areyou", department: "Library - Information Technology",
                                                         edupersonprincipalname: "who@princeton.edu",
                                                         puresidentdepartment: "Library - Information Technology",
                                                         puaffiliation: "stf", departmentnumber: "41999", pustatus: "stf"))
  end

  let(:normal_user) { described_class.from_cas(access_token) }
  let(:pppl_user) { described_class.from_cas(access_token_pppl) }
  let(:super_admin_user) { described_class.new_super_admin("fake1") }

  let(:rd_collection) { Collection.where(code: "RD").first }
  let(:pppl_collection) { Collection.where(code: "PPPL").first }

  let(:csv) { file_fixture("orcid.csv").to_s }
  # rubocop:disable Layout/LineLength
  let(:csv_params) { { "First Name" => "Darryl", "Last Name" => "Williamson", "Net ID" => "fake_netid_dw1234", "PPPL Email" => "fake_email_dwilliamson1234@pppl.gov", "ORCID ID" => "0000-0000-0000-0000" } }
  # rubocop:enable Layout/LineLength

  describe "#from_cas" do
    it "returns a user object with a default collection" do
      user = described_class.from_cas(access_token)
      expect(user).to be_a described_class
      expect(user.default_collection.id).to eq Collection.default.id
    end

    it "sets the proper default collection for a PPPL user" do
      pppl_collection = Collection.where(code: "PPPL").first
      pppl_user = described_class.from_cas(access_token_pppl)
      expect(pppl_user).to be_a described_class
      expect(pppl_user.default_collection.id).to eq pppl_collection.id
    end

    it "sets the CAS info on new" do
      user = described_class.from_cas(access_token_full_extras)
      expect(user.email).to eq "who@princeton.edu"
      expect(user.full_name).to eq "Areyou, Who"
      expect(user.display_name).to eq "Who"
      expect(user.family_name).to eq "Areyou"
    end

    it "updates an existing user with CAS info" do
      # Create a user without CAS info
      described_class.where(uid: "test123").delete_all
      user = described_class.new(uid: "test123", email: "test123@princeton.edu")
      user.save!
      expect(user.display_name).to be nil

      # ...make sure it's updated with CAS info
      user = described_class.from_cas(access_token_full_extras)
      expect(user.email).to eq "who@princeton.edu"
      expect(user.full_name).to eq "Areyou, Who"
      expect(user.display_name).to eq "Who"
      expect(user.family_name).to eq "Areyou"
    end
  end

  describe "#super_admin?" do
    let(:normal_user) { described_class.from_cas(access_token) }

    it "is true if the user is in the super_admin config" do
      expect(super_admin_user.super_admin?).to eq true
    end

    it "is false if the user is not in the super_admin config" do
      expect(normal_user.super_admin?).to eq false
    end

    context "when an error is raised parsing the user IDs of super_admin users" do
      before do
        normal_user
        allow(described_class).to receive(:adapter).and_raise(StandardError)
      end

      it "returns nil" do
        expect(normal_user.super_admin?).to eq false
      end
    end
  end

  describe "#new_for_uid" do
    it "creates the user only once" do
      described_class.where(uid: "test222").delete_all
      user1 = described_class.new_for_uid("test222")
      user2 = described_class.new_for_uid("test222")
      expect(user1.id).to eq user2.id
    end
  end

  describe "#new_from_csv" do
    it "creates the user only once" do
      described_class.where(uid: "fake_netid_dw1234").delete_all
      user1 = described_class.new_from_csv_params(csv_params)
      user2 = described_class.new_from_csv_params(csv_params)
      expect(user1.id).to eq user2.id
    end

    it "updates the ORCID ID but not the name values if they exist" do
      described_class.where(uid: "fake_netid_dw1234").delete_all
      user = described_class.new_from_csv_params(csv_params)
      user.full_name = "Darryl Arthur Williamson"
      user.display_name = "D. Williamson"
      user.orcid = "0000-0000-0000-1111"
      user.save!
      user = described_class.new_from_csv_params(csv_params)
      expect(user.full_name).to eq "Darryl Arthur Williamson"
      expect(user.display_name).to eq "D. Williamson"
      expect(user.orcid).to eq "0000-0000-0000-0000"
    end
  end

  describe "#create_users_from_csv" do
    it "creates users from values supplied in a CSV file" do
      users = described_class.create_users_from_csv(csv)
      expect(users.length).to eq 3
      expect(users.first.full_name).to eq "Jackie Alvarez"
      expect(users.last.full_name).to eq "Kent Jenson"
    end
  end

  describe "#create_default_users" do
    it "creates the default users/collection records" do
      # The data for these tests comes from `default_collections.yml`
      described_class.create_default_users
      fake1 = described_class.find_by(uid: "fake1")
      expect(fake1).to be_super_admin
      admin_user = described_class.find_by(uid: "user1")
      submitter_user = described_class.find_by(uid: "user2")
      rd = Collection.research_data
      expect(admin_user.can_admin?(rd)).to be true
      expect(submitter_user.can_submit?(rd)).to be true
      expect(submitter_user.can_admin?(rd)).to be false
    end
  end

  describe "collection access" do
    it "gives full rights to super_admin users" do
      expect(super_admin_user.can_admin?(pppl_collection.id)).to be true
      expect(super_admin_user.can_submit?(pppl_collection.id)).to be true
      expect(super_admin_user.can_admin?(rd_collection.id)).to be true
      expect(super_admin_user.can_submit?(rd_collection.id)).to be true
      expect(super_admin_user.submitter_collections.count).to eq Collection.count
    end

    it "gives access to research data collection to normal users" do
      expect(normal_user.can_admin?(pppl_collection)).to be false
      expect(normal_user.can_submit?(pppl_collection)).to be false
      expect(normal_user.can_admin?(rd_collection)).to be false
      expect(normal_user.can_submit?(rd_collection)).to be true
      expect(normal_user.submitter_collections.count).to eq 1
    end

    it "gives submit access PPPL collection to PPPL users" do
      expect(pppl_user.can_admin?(pppl_collection)).to be false
      expect(pppl_user.can_submit?(pppl_collection)).to be true
      expect(pppl_user.can_admin?(rd_collection)).to be false
      expect(pppl_user.can_submit?(rd_collection)).to be false
      expect(pppl_user.submitter_collections.count).to eq 1
    end

    it "gives access to the default collection" do
      user = FactoryBot.build :user
      user.add_role(:collection_admin, pppl_collection)
      user.save!
      expect(user.can_submit?(rd_collection)).to be_truthy
    end
  end

  describe "default collection is set on ititalize" do
    it "super admins can access any collection" do
      expect(super_admin_user.submitter_collections.count).to be Collection.count
    end

    it "gives a user submit access to their default collection" do
      expect(normal_user.submitter_collections).to eq [rd_collection]
    end

    it "gives a pppl user submit access to their default collection" do
      expect(pppl_user.submitter_collections).to eq [pppl_collection]
    end
  end

  describe "#orcid" do
    let(:normal_user) { described_class.new }
    let(:orcid) { "0000-0003-1279-3709" }

    it "mutates the ORCID for a given User" do
      expect(normal_user.orcid).to be nil
      normal_user.orcid = orcid
      expect(normal_user.orcid).to eq(orcid)
    end

    context "with an existing ORCID" do
      let(:normal_user) { described_class.new(orcid: orcid) }

      it "accesses an existing ORCID for a given User" do
        expect(normal_user.orcid).to eq(orcid)
      end
    end
  end

  describe "ORCID validation" do
    let(:user) { described_class.new }
    it "performs ORCID validation on save" do
      user.orcid = "1234-1234-1234-1234"
      expect(user.save).to be true

      user.orcid = "1234-1234-1234-ABCD"
      expect(user.save).to be false

      user.orcid = ""
      expect(user.save).to be true
    end
  end

  describe "#update_super_admins" do
    it "updates a user to be a super_admin" do
      user = User.create(uid: "fake1")
      expect(user).not_to be_super_admin
      User.update_super_admins
      expect(user).to be_super_admin
    end
  end

  describe "#disable_messages_from" do
    let(:collection) { Collection.default }
    let(:user) { described_class.create(uid: "test") }

    context "when the user is a super admin" do
      let(:user) { described_class.new_super_admin("test-admin") }

      it "disables email messages for notifications from a Collection" do
        initial_state = user.messages_enabled_from?(collection: collection)
        expect(initial_state).to be false

        user.enable_messages_from(collection: collection)
        user.save!
        user.reload

        enabled_state = user.messages_enabled_from?(collection: collection)
        expect(enabled_state).to be true

        user.disable_messages_from(collection: collection)
        user.save!
        user.reload

        disabled_state = user.messages_enabled_from?(collection: collection)
        expect(disabled_state).to be false
      end
    end

    context "when the user is an administrator for a Collection" do
      before do
        user.add_role(:collection_admin, collection)
        user.save!
      end

      it "disables email messages for notifications from a Collection" do
        initial_state = user.messages_enabled_from?(collection: collection)
        expect(initial_state).to be false

        user.enable_messages_from(collection: collection)
        user.save!
        user.reload

        enabled_state = user.messages_enabled_from?(collection: collection)
        expect(enabled_state).to be true

        user.disable_messages_from(collection: collection)
        user.save!
        user.reload

        disabled_state = user.messages_enabled_from?(collection: collection)
        expect(disabled_state).to be false
      end
    end

    it "raises an ArgumentError" do
      state = user.messages_enabled_from?(collection: collection)
      expect(state).to be false

      expect { user.disable_messages_from(collection: collection) }.to raise_error(ArgumentError, "User #{user.uid} is not an administrator for the collection #{collection.title}")
    end
  end
end
