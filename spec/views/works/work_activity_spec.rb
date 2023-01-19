# frozen_string_literal: true
require "rails_helper"

describe "Change History, AKA Provenance" do
  let(:work) { FactoryBot.create :draft_work }
  let(:partial) { "works/work_activity_provenance" }

  it "handles no activity" do
    assign(:changes, [])

    render(partial: partial, locals: { can_add_provenance_note: false })

    expect(rendered).to include("No activity")
  end

  it "shows oldest message first, when array is in the same order" do

  end

  it "shows oldest message first, when array is in the reverse order" do

  end 
end

describe "Messages" do
  let(:work) { FactoryBot.create :draft_work } # Needed only to check work.submission_notes.
  let(:partial) { "works/work_activity_messages" }

  it "handles no messages" do
    assign(:work, work)
    assign(:messages, [])
    render(partial: partial)
    expect(rendered).to include("No messages")
  end

  it "shows newest message first, when array is in the same order" do

  end

  it "shows newest message first, when array is in the reverse order" do

  end  
end