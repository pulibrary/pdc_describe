class DeparmentCommunity < ActiveRecord::Migration[7.2]
  def change
    Work.where("metadata @> ?", JSON.dump(communities: ["Department of Geosciences"])).each do |work|
      communities = work.resource.communities
      work.resource.communities = communities.map {|community| community == "Department of Geosciences" ? "Geosciences" : community }
      work.save
    end
  end
end
