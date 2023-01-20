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
