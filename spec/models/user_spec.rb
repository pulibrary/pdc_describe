# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  before { Group.create_defaults }

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

  let(:rd_group) { Group.where(code: "RD").first }
  let(:pppl_group) { Group.where(code: "PPPL").first }

  let(:csv) { file_fixture("orcid.csv").to_s }
  # rubocop:disable Layout/LineLength
  let(:csv_params) { { "First Name" => "Darryl", "Last Name" => "Williamson", "Net ID" => "fake_netid_dw1234", "PPPL Email" => "fake_email_dwilliamson1234@pppl.gov", "ORCID ID" => "0000-0000-0000-0000" } }
  # rubocop:enable Layout/LineLength

  describe "#from_cas" do
    it "returns a user object with a default group" do
      user = described_class.from_cas(access_token)
      expect(user).to be_a described_class
      expect(user.default_group.id).to eq Group.default.id
      expect(user.default_group.messages_enabled_for?(user:)).to be_truthy
    end

    it "sets the proper default group for a PPPL user" do
      pppl_group = Group.where(code: "PPPL").first
      pppl_user = described_class.from_cas(access_token_pppl)
      expect(pppl_user).to be_a described_class
      expect(pppl_user.default_group.id).to eq pppl_group.id
      expect(pppl_user.default_group.messages_enabled_for?(user: pppl_user)).to be_truthy
    end

    it "sets the CAS info on new" do
      user = described_class.from_cas(access_token_full_extras)
      expect(user.email).to eq "who@princeton.edu"
      expect(user.full_name).to eq "Areyou, Who"
      expect(user.given_name).to eq "Who"
      expect(user.family_name).to eq "Areyou"
    end

    it "updates an existing user with CAS info" do
      # Create a user without CAS info
      described_class.where(uid: "test123").delete_all
      user = described_class.new(uid: "test123", email: "test123@princeton.edu")
      user.save!
      expect(user.given_name).to be nil

      # ...make sure it's updated with CAS info
      user = described_class.from_cas(access_token_full_extras)
      expect(user.email).to eq "who@princeton.edu"
      expect(user.full_name).to eq "Areyou, Who"
      expect(user.given_name).to eq "Who"
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
      user.given_name = "D. Williamson"
      user.orcid = "0000-0000-0000-1111"
      user.save!
      user = described_class.new_from_csv_params(csv_params)
      expect(user.full_name).to eq "Darryl Arthur Williamson"
      expect(user.given_name).to eq "D. Williamson"
      expect(user.orcid).to eq "0000-0000-0000-0000"
    end
  end

  describe "#create_users_from_csv" do
    it "creates users from values supplied in a CSV file" do
      users = described_class.create_users_from_csv(csv)
      expect(users.length).to eq 3
      expect(users.first.full_name).to eq "Jackie Alvarez"
      expect(users.first.given_name).to eq "Jackie"
      expect(users.first.family_name).to eq "Alvarez"
      expect(users.last.full_name).to eq "Kent Jenson"
    end
  end

  describe "#create_default_users" do
    it "creates the default users/group records" do
      # The data for these tests comes from `default_groups.yml`
      described_class.create_default_users
      fake1 = described_class.find_by(uid: "fake1")
      expect(fake1).to be_super_admin
      admin_user = described_class.find_by(uid: "user1")
      submitter_user = described_class.find_by(uid: "user2")
      rd = Group.research_data
      expect(admin_user.can_admin?(rd)).to be true
      expect(submitter_user.can_submit?(rd)).to be true
      expect(submitter_user.can_admin?(rd)).to be false
    end
  end

  describe "group access" do
    it "gives full rights to super_admin users" do
      expect(super_admin_user.can_admin?(pppl_group.id)).to be true
      expect(super_admin_user.can_submit?(pppl_group.id)).to be true
      expect(super_admin_user.can_admin?(rd_group.id)).to be true
      expect(super_admin_user.can_submit?(rd_group.id)).to be true
      expect(super_admin_user.submitter_groups.count).to eq Group.count
    end

    it "gives access to research data group to normal users" do
      expect(normal_user.can_admin?(pppl_group)).to be false
      expect(normal_user.can_submit?(pppl_group)).to be false
      expect(normal_user.can_admin?(rd_group)).to be false
      expect(normal_user.can_submit?(rd_group)).to be true
      expect(normal_user.submitter_groups.count).to eq 1
    end

    it "gives submit access PPPL group to PPPL users" do
      expect(pppl_user.can_admin?(pppl_group)).to be false
      expect(pppl_user.can_submit?(pppl_group)).to be true
      expect(pppl_user.can_admin?(rd_group)).to be false
      expect(pppl_user.can_submit?(rd_group)).to be false
      expect(pppl_user.submitter_groups.count).to eq 1
    end

    it "gives access to the default group" do
      user = FactoryBot.build :user
      user.add_role(:group_admin, pppl_group)
      user.save!
      expect(user.can_submit?(rd_group)).to be_truthy
    end

    context "and admin user" do
      it "allows the admin to choose either group" do
        normal_user.add_role(:group_admin, pppl_group)
        expect(normal_user.submitter_groups.count).to eq 2
      end
    end
  end

  describe "default group is set on ititalize" do
    it "super admins can access any group" do
      expect(super_admin_user.submitter_groups.count).to be Group.count
    end

    it "gives a user submit access to their default group" do
      expect(normal_user.submitter_groups).to eq [rd_group]
    end

    it "gives a pppl user submit access to their default group" do
      expect(pppl_user.submitter_groups).to eq [pppl_group]
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
      let(:normal_user) { described_class.new(orcid:) }

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

  describe "#submitter_or_admin_groups" do
    it "returns both admin and submitter groups" do
      user = FactoryBot.create(:user)
      group1 = FactoryBot.create(:group)
      group2 = FactoryBot.create(:group)
      group3 = FactoryBot.create(:group)
      user.add_role(:submitter, group1)
      user.add_role(:group_admin, group2)
      user.add_role(:group_admin, group3)
      user.add_role(:submitter, group3)
      # should contain the rd_group by default
      expect(user.submitter_or_admin_groups).to contain_exactly(group1, group2, group3, rd_group)
    end
  end

  describe "#full_name_safe" do
    it "returns the full name" do
      user = FactoryBot.create(:user)
      expect(user.full_name_safe).to eq(user.full_name)
    end

    it "returns the uid if the full name is empty" do
      user = FactoryBot.create(:user, given_name: "", family_name: "", full_name: "")
      expect(user.full_name_safe).to eq(user.uid)
    end

    it "returns the uid if the full name only has spaces" do
      user = FactoryBot.create(:user, full_name: "  ")
      expect(user.full_name_safe).to eq(user.uid)
    end
  end
end
