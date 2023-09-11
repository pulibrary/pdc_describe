# frozen_string_literal: true

# A service to update metadata across PDC Describe
class WorkUpdateMetadataService
  RENAMED_PPPL_SUBCOMMUNITIES = [
    {
      old: "Plasma Science & Technology",
      new: "Discovery Plasma Science"
    }
  ].freeze

  # For each renamed pppl subcommunity, traverse all of the works
  # and update the value
  def self.update_pppl_subcommunities(user, commandline: false)
    Work.all.each do |work|
      resource_before = work.resource.dup
      RENAMED_PPPL_SUBCOMMUNITIES.each do |renamed_subcommunity|
        sc = work.resource.subcommunities
        next unless sc.include? renamed_subcommunity[:old]
        puts "Updating work #{work.id}" if commandline
        work.resource.subcommunities = new_subcommunities(sc, renamed_subcommunity)
      end
      work.save
      resource_after = work.resource
      resource_compare = ResourceCompareService.new(resource_before, resource_after)
      WorkActivity.add_work_activity(work.id, resource_compare.differences.to_json, user.id, activity_type: WorkActivity::CHANGES)
    end
  end

  # Given a list of subcommunities, and a Hash from RENAMED_PPPL_SUBCOMMUNITIES,
  # replace all instances of :old with :new
  def self.new_subcommunities(sc, renamed_subcommunity)
    new_subcommunities = []
    sc.each do |subcommunity|
      new_subcommunities << if subcommunity == renamed_subcommunity[:old]
                              renamed_subcommunity[:new]
                            else
                              subcommunity
                            end
    end
    new_subcommunities
  end
end
