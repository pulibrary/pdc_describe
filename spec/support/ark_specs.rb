# frozen_string_literal: true

def stub_ark
  @ezid ||= instance_double(Ezid::Identifier)
  allow(Ezid::Identifier).to receive(:find).and_return(@ezid)
  @ezid
end
