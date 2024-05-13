# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorksController, type: :routing do
  describe "routing" do
    it "routes to #edit_wizard" do
      expect(get: "/works/1/edit-wizard").to route_to("works_wizard#edit_wizard", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/works/1/update-wizard").to route_to("works_wizard#update_wizard", id: "1")
    end

    it "routes to #attachment_select" do
      expect(get: "/works/1/attachment-select").to route_to("works_wizard#attachment_select", id: "1")
    end

    it "routes to #attachment_selected" do
      expect(post: "/works/1/attachment-select").to route_to("works_wizard#attachment_selected", id: "1")
    end

    it "routes to #new_submission" do
      expect(get: "/works/1/new-submission-delete").to route_to("works_wizard_new_submission#new_submission_delete", id: "1")
    end
  end
end
