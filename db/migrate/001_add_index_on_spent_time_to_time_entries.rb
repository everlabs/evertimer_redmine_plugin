# Explicit up/down: with `change`, a VERSION=0 rollback re-evaluates the guard after
# 002's down has recreated the index, so the index would never be removed.
class AddIndexOnSpentTimeToTimeEntries < ActiveRecord::Migration[4.2]
  def up
    unless index_exists?(:time_entries, :spent_on)
      add_index :time_entries, :spent_on
    end
  end

  def down
    if index_exists?(:time_entries, :spent_on)
      remove_index :time_entries, :spent_on
    end
  end
end
