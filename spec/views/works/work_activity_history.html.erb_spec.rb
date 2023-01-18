# frozen_string_literal: true
require "rails_helper"

describe "works/_work_activity_history.html.erb" do
  let(:work) { FactoryBot.create :draft_work }

  it "renders" do
    assign(:work, work)
    assign(:messages, [])
    assign(:changes, [])

    render(partial: 'works/work_activity_history.html.erb', locals: {can_add_provenance_note: false})

    expect(rendered).to include("TODO")
  end
end
