# frozen_string_literal: true
require "rails_helper"

RSpec.describe UploadSnapshotsController, type: :routing do
  describe "routing" do
    it "routes to #create via POST" do
      expect(post: "/upload-snapshots").to route_to("upload_snapshots#create")
    end

    it "routes to #destroy via DELETE" do
      expect(delete: "/upload-snapshots/1").to route_to("upload_snapshots#destroy", id: "1")
    end
  end
end
