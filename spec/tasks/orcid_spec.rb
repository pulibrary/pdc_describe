require 'rake'

describe "orcid_populate" do
  context "populate ORCID IDs from a spreadsheet" do

    before do
      ENV["SOURCE_CSV"] = 'spec/fixtures/orcid.csv'

    end

    it "creates a user with an ORCID ID when that user does not exist and updates an existing user's ORCID ID and no other existing user values" do
      Rake::Task["orcid:populate"].invoke

      # assert the expected behaviour here related for foo case
    end
  end
end
