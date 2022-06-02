# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each, mock_ezid_api: true) do
    @ezid = "ark:/99999/fk4tq65d6k"
    # This is not `instance_double` given that the `#modify` must be stubbed as is private
    @identifier = double(Ezid::Identifier)

    # For minting EZIDs
    allow(@identifier).to receive(:id).and_return(@ezid)
    allow(Ezid::Identifier).to receive(:mint).and_return(@identifier)

    # For requesting EZIDs
    @ezid_metadata_values = {
      "_updated" => "1611860047",
      "_target" => "https://dataspace.princeton.edu/handle/88435/dsp01qb98mj541",
      "_profile" => "erc",
      "_export" => "yes",
      "_owner" => "pudiglib",
      "_ownergroup" => "pudiglib",
      "_created" => "1611860047",
      "_status" => "public"
    }
    @ezid_metadata = Ezid::Metadata.new(@ezid_metadata_values)

    allow(Ezid::Identifier).to receive(:find).and_return(@identifier)

    # For updating EZID metadata
    allow(@identifier).to receive(:metadata).and_return(@ezid_metadata)
    allow(@identifier).to receive(:id).and_return(@ezid)
    allow(@identifier).to receive(:modify)
    allow(@identifier).to receive(:target).and_return(@ezid_metadata_values["_target"])
    allow(@identifier).to receive(:target=)
    allow(@identifier).to receive(:save!)
  end
end
