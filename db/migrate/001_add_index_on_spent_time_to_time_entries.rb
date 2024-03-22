class AddIndexOnSpentTimeToTimeEntries < ActiveRecord::Migration[4.2]
  def change
    add_index :time_entries, :spent_on
  end
end
