class AddIndexOnSpentTimeToTimeEntries < ActiveRecord::Migration[4.2]
  def change
    unless index_exists?(:time_entries, :spent_on)
      add_index :time_entries, :spent_on
    end
  end
end
