# frozen_string_literal: true
require "rails_helper"

describe "Change History, AKA Provenance" do
  let(:user) { FactoryBot.create :user }
  let(:work) { FactoryBot.create :draft_work }
  let(:work_decorator) { WorkDecorator.new(work, user) }
  let(:partial) { "works/work_activity_provenance" }
  let(:older) do
    WorkActivity.add_work_activity(work.id, "older", user.id,
      activity_type: WorkActivity::SYSTEM, created_at: "2021-01-01")
  end
  let(:newer) do
    WorkActivity.add_work_activity(work.id, "newer", user.id,
      activity_type: WorkActivity::SYSTEM, created_at: "2022-01-01")
  end

  it "handles no activity" do
    assign(:work_decorator, work_decorator)
    render(partial:, locals: { can_add_provenance_note: false })
    expect(rendered).to include("No activity")
  end

  it "handles metadata changes" do
    WorkActivity.add_work_activity(work.id, JSON.dump({ a_field: [{ action: "changed", from: "old", to: "new" }] }), user.id,
                                   activity_type: WorkActivity::CHANGES)
    assign(:work_decorator, work_decorator)
    render(partial:, locals: { can_add_provenance_note: false })
    expect(rendered).to include("<del>old</del><ins>new</ins>")
  end

  it "handles file changes" do
    WorkActivity.add_work_activity(work.id, { action: "added" }.to_json, user.id, activity_type: WorkActivity::FILE_CHANGES)
    assign(:work_decorator, work_decorator)
    render(partial:, locals: { can_add_provenance_note: false })
    expect(rendered).to include("Files Added:")
  end

  it "handles prov note" do
    WorkActivity.add_work_activity(work.id, "note!", user.id, activity_type: WorkActivity::PROVENANCE_NOTES)
    assign(:work_decorator, work_decorator)
    render(partial:, locals: { can_add_provenance_note: false })
    expect(rendered).to include("note!")
  end

  it "handles error" do
    WorkActivity.add_work_activity(work.id, "error!", user.id, activity_type: WorkActivity::DATACITE_ERROR)
    assign(:work_decorator, work_decorator)
    render(partial:, locals: { can_add_provenance_note: false })
    expect(rendered).to include("error!")
  end

  it "handles backdated prov note" do
    older
    assign(:work_decorator, work_decorator)
    render(partial:, locals: { can_add_provenance_note: false })
    expect(rendered).to include("January 01, 2021 00:00 (backdated event created")
  end

  it "shows oldest change first, when array is in the same order" do
    older
    newer
    assign(:work_decorator, work_decorator)
    render(partial:, locals: { can_add_provenance_note: false })
    expect(rendered).to match(/older.*newer/m)
  end

  it "still shows oldest change first, when array is in the reverse order" do
    newer
    older
    assign(:work_decorator, work_decorator)
    render(partial:, locals: { can_add_provenance_note: false })
    expect(rendered).to match(/older.*newer/m)
  end
end
