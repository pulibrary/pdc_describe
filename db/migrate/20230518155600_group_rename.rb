class GroupRename < ActiveRecord::Migration[6.1]
  def up
    group = Group.where(code: "RD").first
    if group
      group.title = "Princeton Research Data Service (PRDS)"
      group.save!
    end
    pppl_group = Group.where(code: "PPPL").first
    if pppl_group
      pppl_group.title = "Princeton Plasma Physics Lab (PPPL)"
      pppl_group.save!
    end
  end
  def down
    group = Group.where(code: "RD").first
    if group
      group.title = "Research Data"
      group.save!
    end
    pppl_group = Group.where(code: "PPPL").first
    if pppl_group
      pppl_group.title = "Princeton Plasma Physics Laboratory"
      pppl_group.save!
    end
  end
end
