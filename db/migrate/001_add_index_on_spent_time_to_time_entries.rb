class AddIndexOnSpentTimeToTimeEntries < ActiveRecord::Migration[6.1]
  def change
    add_index :time_entries, :spent_on
  end
end
