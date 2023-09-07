class AddEmbargoDateToWorks < ActiveRecord::Migration[6.1]
  def change
    add_column :works, :embargo_date, :date
  end
end
