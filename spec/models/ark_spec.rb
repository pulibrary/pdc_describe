# frozen_string_literal: true
require "rails_helper"

RSpec.describe Ark, type: :model do
  describe ".valid?" do
    let(:id) { "id" }

    context "when the ARK references a non-existent EZID" do
      before do
        stub_request(:get, "https://ezid.cdlib.org/id/#{id}").to_return(status: 400, body: "error: bad request - invalid identifier")

        # This is a work-around for WebMock
        allow(Ezid::Identifier).to receive(:find).and_raise(Net::HTTPServerException, '400 "Bad Request"')
      end

      it "returns false" do
        expect(described_class.valid?(id)).to be false
      end
    end

    context "when the ARK references an existing EZID" do
      let(:response_body) do
        %(
          success: ark:/99999/fk4cz3dh0
          _created: 1300812337
          _updated: 1300913550
          _target: http://www.gutenberg.org/ebooks/7178
          _profile: erc
          erc.who: Proust, Marcel
          erc.what: Remembrance of Things Past
          erc.when: 1922
        )
      end
      let(:identifier) { instance_double(Ezid::Identifier) }

      before do
        stub_request(:get, "https://ezid.cdlib.org/id/#{id}").to_return(status: 200, body: response_body)
        # This is a work-around for WebMock
        allow(Ezid::Identifier).to receive(:find).and_return(identifier)
      end

      it "returns true" do
        expect(described_class.valid?(id)).to be true
      end
    end
  end
end
