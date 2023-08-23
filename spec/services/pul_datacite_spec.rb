# frozen_string_literal: true
require "rails_helper"

RSpec.describe PULDatacite do
  let(:subject) { described_class.new(work) }
  let(:fake_datacite) { stub_datacite_doi }
  before do
    @datacite_user = Rails.configuration.datacite.user
  end

  after do
    Rails.configuration.datacite.user = @datacite_user
  end

  describe "#draft_doi" do
    let(:work) { FactoryBot.create :draft_work, doi: "" }
    let(:datacite_response) { instance_double Datacite::Response, doi: "10.34770/abc123" }
    before do
      allow(fake_datacite).to receive(:autogenerate_doi).and_return(Success(datacite_response))
    end

    it "returns the test doi" do
      Rails.configuration.datacite.user = nil
      expect(subject.draft_doi).to eq("10.34770/tbd")
      expect(fake_datacite).not_to have_received(:autogenerate_doi)
    end

    context "we have a datacite user" do
      before do
        Rails.configuration.datacite.user = "abc"
      end

      it "calls out to datacite" do
        expect(subject.draft_doi).to eq("10.34770/abc123")
        expect(fake_datacite).to have_received(:autogenerate_doi)
      end

      context "there is an error" do
        let(:faraday_response) { instance_double Faraday::Response, reason_phrase: "Bad response", status: 500 }
        before do
          allow(fake_datacite).to receive(:autogenerate_doi).and_return(Failure(faraday_response))
        end

        it "raises an exception" do
          expect { subject.draft_doi }.to raise_error("Error generating DOI. 500 / Bad response")
          expect(fake_datacite).to have_received(:autogenerate_doi)
        end
      end
    end
  end

  describe "#publish_doi" do
    let(:datacite_response) { instance_double Datacite::Response, doi: "10.34770/abc123" }
    let(:user) { FactoryBot.create :user }
    let(:work) { FactoryBot.create :draft_work, doi: "#{Rails.configuration.datacite.prefix}/abc123" }
    before do
      allow(fake_datacite).to receive(:update).and_return(Success(datacite_response))
    end

    it "skips the update to datacite" do
      Rails.configuration.datacite.user = nil
      subject.publish_doi(user)
      expect(fake_datacite).not_to have_received(:update)
    end

    context "we have a datacite user" do
      before do
        Rails.configuration.datacite.user = "abc"
      end

      it "sends an update to datacite" do
        expect { subject.publish_doi(user) }.to change { WorkActivity.count }.by 0
        expect(fake_datacite).to have_received(:update).with(hash_including(id: work.doi))
      end

      context "there is an error" do
        let(:faraday_response) { instance_double Faraday::Response, reason_phrase: "Bad response", status: 500 }
        before do
          allow(fake_datacite).to receive(:update).and_return(Failure(faraday_response))
        end

        it "captures the error in a work activity" do
          expect { subject.publish_doi(user) }.to change { WorkActivity.count }.by 1
          expect(fake_datacite).to have_received(:update).with(hash_including(id: work.doi))
        end
      end

      context "the doi is not ours" do
        let(:work) { FactoryBot.create :draft_work, doi: "1111/abc123" }
        before do
          allow(Honeybadger).to receive(:notify)
        end

        it "does not send an update to datacite" do
          expect { subject.publish_doi(user) }.to change { WorkActivity.count }.by 0
          expect(fake_datacite).not_to have_received(:update).with(hash_including(id: work.doi))
          expect(Honeybadger).to have_received(:notify).with("Publishing for a DOI we do not own and no ARK is present: 1111/abc123")
        end
      end
    end
  end
end
