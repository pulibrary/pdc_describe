# frozen_string_literal: true
require "rails_helper"

RSpec.describe "/works", type: :request do
  let(:user) { FactoryBot.create :user }

  describe "GET /work" do
    let(:work) do
      FactoryBot.create(:tokamak_work)
    end

    before do
      stub_work_s3_requests(work: work)
    end

    it "will not show a work page unless the user is logged in" do
      get work_url(work)
      expect(response.code).to eq "302"
      redirect_location = response.header["Location"]
      expect(redirect_location).to eq "http://www.example.com/sign_in"
    end

    context "when authenticated" do
      before do
        sign_in(user)
      end

      it "will show the work page displaying the work metadata" do
        get work_url(work)

        expect(response.code).to eq "200"
        expect(response.body).to include("Electron Temperature Gradient Driven Transport Model for Tokamak Plasmas")
      end

      context "when the work does not have a valid collection" do
        let(:work) do
          stubbed = instance_double(Work)
          allow(stubbed).to receive(:s3_object_key).and_return("test-key")
          stubbed
        end

        before do
          allow(work).to receive(:id).and_return("test-id")
          allow(work).to receive(:activities).and_return([])
          allow(work).to receive(:collection).and_return(nil)
          allow(work).to receive(:attach_s3_resources)

          allow(Work).to receive(:find).and_return(work)
        end

        it "will raise an error" do
          expect { get work_url(work) }.to raise_error(Work::InvalidCollectionError, "The Work test-id does not belong to any Collection")
        end
      end
    end
  end
end
