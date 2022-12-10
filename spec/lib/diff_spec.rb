# frozen_string_literal: true

require_relative "../../app/lib/diff"

RSpec.describe SimpleDiff do
  it "handles complete change" do
    expect(SimpleDiff.new("cat", "dog").to_html).to eq "<del>cat</del><ins>dog</ins>"
  end
  it "handles single character change" do
    expect(SimpleDiff.new("cat", "bat").to_html).to eq "<del>c</del><ins>b</ins>at"
  end
  it "handles nil old" do
    expect(SimpleDiff.new(nil, "dog").to_html).to eq "<ins>dog</ins>"
  end
  it "handles nil new" do
    expect(SimpleDiff.new("dog", nil).to_html).to eq "<del>dog</del>"
  end
  it "handles addition" do
    expect(SimpleDiff.new("dog", "In the dog house").to_html).to eq "<ins>In the </ins>dog<ins> house</ins>"
  end
  it "handles deletion" do
    expect(SimpleDiff.new("The cow jumped", "cow").to_html).to eq "<del>The </del>cow<del> jumped</del>"
  end
  it "handles mixed" do
    expect(SimpleDiff.new("quick brown", "brown fox").to_html).to eq "<del>quick </del>brown<ins> fox</ins>"
  end
  it "encodes html" do
    expect(SimpleDiff.new("1 < 2", "2 > 1").to_html).to eq "<del>1</del><ins>2</ins> <del>&lt;</del><ins>&gt;</ins> <del>2</del><ins>1</ins>"
  end
end
