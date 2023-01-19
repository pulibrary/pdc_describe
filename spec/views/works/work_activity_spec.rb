# frozen_string_literal: true
require "rails_helper"

describe "Change History, AKA Provenance" do
  let(:work) { FactoryBot.create :draft_work }
  let(:partial) { "works/work_activity_provenance.html.erb" }

  it "renders" do
    assign(:work, work)
    assign(:changes, [])

    render(partial: partial, locals: { can_add_provenance_note: false })

    expect(rendered).to include("No activity")
  end
end

describe "Messages" do
  let(:work) { FactoryBot.create :draft_work }
  let(:partial) { "works/work_activity_messages.html.erb" }

  it "renders" do
    assign(:work, work)
    assign(:messages, [])

    render(partial: partial)

    expect(rendered).to include("No messages")
  end
end