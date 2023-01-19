# frozen_string_literal: true
require "rails_helper"

describe "Change History, AKA Provenance" do
  let(:user) { FactoryBot.create :user }
  let(:work) { FactoryBot.create :draft_work }
  let(:partial) { "works/work_activity_provenance" }
  let(:older) do
    WorkActivity.new(
      work_id: 0,
      activity_type: WorkActivity::SYSTEM,
      message: "older",
      created_by_user_id: user.id,
      created_at: "2021-01-01"
    )
  end
  let(:newer) do
    WorkActivity.new(
      work_id: 0,
      activity_type: WorkActivity::SYSTEM,
      message: "newer",
      created_by_user_id: user.id,
      created_at: "2022-01-01"
    )
  end

  it "handles no activity" do
    assign(:changes, [])
    render(partial: partial, locals: { can_add_provenance_note: false })
    expect(rendered).to include("No activity")
  end

  it "shows oldest change first, when array is in the same order" do
    assign(:changes, [older, newer])
    render(partial: partial, locals: { can_add_provenance_note: false })
    expect(rendered).to match(/older.*newer/m)
  end

  it "shows oldest change first, when array is in the reverse order" do
    assign(:changes, [newer, older])
    render(partial: partial, locals: { can_add_provenance_note: false })
    expect(rendered).to match(/older.*newer/m)
  end
end
