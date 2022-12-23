# frozen_string_literal: true

require_relative "../../app/lib/diff_tools"

RSpec.describe DiffTools::SimpleDiff do
  it "handles complete change" do
    expect(DiffTools::SimpleDiff.new("cat", "dog").to_html).to eq "<del>cat</del><ins>dog</ins>"
  end
  it "handles single character change" do
    expect(DiffTools::SimpleDiff.new("cat", "bat").to_html).to eq "<del>c</del><ins>b</ins>at"
  end

  it "handles nil old" do
    expect(DiffTools::SimpleDiff.new(nil, "dog").to_html).to eq "<ins>dog</ins>"
  end
  it "handles nil new" do
    expect(DiffTools::SimpleDiff.new("dog", nil).to_html).to eq "<del>dog</del>"
  end

  it "handles addition" do
    expect(DiffTools::SimpleDiff.new("dog", "In the dog house").to_html).to eq "<ins>In the </ins>dog<ins> house</ins>"
  end
  it "handles deletion" do
    expect(DiffTools::SimpleDiff.new("The cow jumped", "cow").to_html).to eq "<del>The </del>cow<del> jumped</del>"
  end
  it "handles mixed" do
    expect(DiffTools::SimpleDiff.new("quick brown", "brown fox").to_html).to eq "<del>quick </del>brown<ins> fox</ins>"
  end

  it "handles number to equivalent string" do
    expect(SimpleDiff.new(2022, "2022").to_html).to eq "2022"
  end
  it "handles string to equivalent number" do
    expect(SimpleDiff.new("2022", 2022).to_html).to eq "2022"
  end
  it "handles numbers" do
    expect(SimpleDiff.new(2022, 2023).to_html).to eq "202<del>2</del><ins>3</ins>"
  end

  it "encodes html" do
    expect(DiffTools::SimpleDiff.new("1 < 2", "2 > 1").to_html).to eq "<del>1</del><ins>2</ins> <del>&lt;</del><ins>&gt;</ins> <del>2</del><ins>1</ins>"
  end

  it "abbreviates really long strings" do
    expect(DiffTools::SimpleDiff.new(
      "This does not repeat the entire string if its just a tiny typo in the middle that changes.",
      "This does not repeat the entire string if it's just a tiny typo in the middle that changes."
    ).to_html).to eq "This does not ... string if it<ins>&#39;</ins>s just a ... middle that changes."
  end
end
