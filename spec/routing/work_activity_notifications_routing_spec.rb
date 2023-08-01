# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkActivityNotificationsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/work_activity_notifications").to route_to("work_activity_notifications#index")
    end

    it "routes to #show" do
      expect(get: "/work_activity_notifications/1").to route_to("work_activity_notifications#show", id: "1")
    end
  end
end
