Sequel.migration do
  up do
    alter_table(:posts) do
      drop_index [:thread_id, :num]
      add_index [:thread_id, :num], :unique => true
    end
  end
end
