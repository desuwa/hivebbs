Sequel.migration do
  up do
    add_column :threads, :locked, 'smallint', :null => false, :default => 0
    add_column :threads, :pinned, 'smallint', :null => false, :default => 0
  end
  
  down do
    drop_column :threads, :locked
    drop_column :threads, :pinned
  end
end
