# frozen_string_literal: true
require "rails_helper"

describe "Messages" do
  let(:user) { FactoryBot.create :user }
  let(:work) { FactoryBot.create :draft_work }
  let(:partial) { "works/work_activity_messages" }
  let(:older) do
    WorkActivity.add_work_activity(work.id, "older", user.id,
      activity_type: WorkActivity::MESSAGE, created_at: "2021-01-01")
  end
  let(:newer) do
    WorkActivity.add_work_activity(work.id, "newer", user.id,
      activity_type: WorkActivity::MESSAGE, created_at: "2022-01-01")
  end

  it "handles no messages" do
    assign(:work, work)
    assign(:messages, [])
    render(partial: partial)
    expect(rendered).to include("No messages")
  end

  it "handles unknown user" do
    assign(:work, work)
    assign(:messages, [WorkActivity.add_work_activity(work.id, "message!", nil,
      activity_type: WorkActivity::MESSAGE)])
    render(partial: partial)
    expect(rendered).to include("Unknown user outside the system")
  end

  it "handles submission notes" do
    work.submission_notes = "submission note!"
    assign(:work, work)
    assign(:messages, [WorkActivity.add_work_activity(work.id, "message!", user.id,
      activity_type: WorkActivity::MESSAGE)])
    render(partial: partial)
    expect(rendered).to include("submission note!")
  end

  it "handles message" do
    assign(:work, work)
    assign(:messages, [WorkActivity.add_work_activity(work.id, "message!", user.id,
      activity_type: WorkActivity::MESSAGE)])
    render(partial: partial)
    expect(rendered).to include("message!")
    expect(rendered).to include("(@#{user.uid})")
  end

  it "handles notification" do
    assign(:work, work)
    assign(:messages, [WorkActivity.add_work_activity(work.id, "notification!", user.id,
      activity_type: WorkActivity::NOTIFICATION)])
    render(partial: partial)
    expect(rendered).to include("notification!")
    expect(rendered).to include("(@#{user.uid})")
  end

  it "shows newest message first, when array is in the same order" do
    assign(:work, work)
    assign(:messages, [newer, older])
    render(partial: partial)
    expect(rendered).to match(/newer.*older/m)
  end

  it "still shows newest message first, when array is in the reverse order" do
    assign(:work, work)
    assign(:messages, [older, newer])
    render(partial: partial)
    expect(rendered).to match(/newer.*older/m)
  end
end
