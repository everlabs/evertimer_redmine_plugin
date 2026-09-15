class ReplaceSpentOnIndexWithCompositeOnTimeEntries < ActiveRecord::Migration[4.2]
  def up
    unless index_exists?(:time_entries, [:user_id, :spent_on])
      add_index :time_entries, [:user_id, :spent_on]
    end
    if index_exists?(:time_entries, :spent_on)
      remove_index :time_entries, :spent_on
    end
  end

  def down
    unless index_exists?(:time_entries, :spent_on)
      add_index :time_entries, :spent_on
    end
    if index_exists?(:time_entries, [:user_id, :spent_on])
      remove_index :time_entries, column: [:user_id, :spent_on]
    end
  end
end
