# frozen_string_literal: true
require "rails_helper"
require "ostruct"

describe WorkCompareService do
  it "detects identical objects" do
    work1 = FactoryBot.build(:shakespeare_and_company_work)
    work2 = FactoryBot.build(:shakespeare_and_company_work)
    compare = described_class.new(work1, work2)
    expect(compare.identical?).to be true
  end

  it "detects changes in the resource" do
    work1 = FactoryBot.build(:shakespeare_and_company_work)
    work2 = FactoryBot.build(:shakespeare_and_company_work)
    work2 .resource.description = "hello"
    compare = described_class.new(work1, work2)
    expect(compare.identical?).to be false
    expect(compare.differences[:description].first[:action]).to be :changed
    expect(compare.differences[:description].first[:to]).to be "hello"
  end

  it "detects changes in the group" do
    work1 = FactoryBot.build(:shakespeare_and_company_work)
    work2 = FactoryBot.build(:shakespeare_and_company_work)
    work2.group = Group.plasma_laboratory
    compare = described_class.new(work1, work2)
    expect(compare.identical?).to be false
  end

  describe "##update_work" do
    it "updates the work and log the changes" do
      work = FactoryBot.build(:shakespeare_and_company_work)
      current_user = work.created_by_user
      update_params = {
                        group_id: Group.plasma_laboratory.id,
                        embargo_date: DateTime.now,
                        resource: work.resource
                      }
      
      expect { 
        expect(described_class.update_work(work:, update_params:, current_user:)).to be_truthy
      }.to change { work.work_activity.count }.by(1)
    end
  end
end
