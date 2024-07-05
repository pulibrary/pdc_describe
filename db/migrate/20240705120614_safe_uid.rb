class SafeUid < ActiveRecord::Migration[6.1]
  def change
    # update any exisitng user to have a safe uid so that correct user will be found when the user logs in
    User.where(" uid like '%@%'").each do |user|
      safe_uid = User.safe_uid(user.uid)
      user.uid = safe_uid
      user.save
    end
  end
end
