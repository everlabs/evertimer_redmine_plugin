# Explicit up/down rather than `change`: with a reversible `change`, a full rollback
# (VERSION=0) reverts 002 first — whose `down` re-adds the single-column spent_on index —
# and then replays this migration inside `revert`, where the `unless index_exists?` guard
# is evaluated live. It would see the index 002 had just recreated, skip the block, and so
# never record the add_index whose inverse remove_index the rollback depends on. The index
# survived the rollback, contradicting the README's uninstall contract. Running the guard
# on each side explicitly makes both directions correct.
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
