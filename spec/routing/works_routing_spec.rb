# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorksController, type: :routing do
  describe "routing" do
    it "routes to #show" do
      expect(get: "/works/1").to route_to("works#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/works/1/edit").to route_to("works#edit", id: "1")
    end

    it "routes to #update via PUT" do
      expect(put: "/works/1").to route_to("works#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/works/1").to route_to("works#update", id: "1")
    end

    context "when the Work has an ARK" do
      let(:ark) { "dsp01zc77st047" }

      it "routes to #resolve_ark" do
        expect(get: "/ark/#{ark}").to route_to("works#resolve_ark", ark: ark)
      end
    end

    context "when the Work has a DOI" do
      let(:doi) { "34770" }

      it "routes to #resolve_doi" do
        expect(get: "/doi/#{doi}").to route_to("works#resolve_doi", doi: doi)
      end
    end
  end
end
