opts = {
  engine: 'InnoDB',
  charset: 'utf8',
  collate: 'utf8_general_ci'
}

case DB.database_type
when :mysql
  collate_bin = 'ascii_bin'
when :sqlite
  collate_bin = 'binary'
when :postgres
  collate_bin = nil
else
  collate_bin = nil
end

Sequel.migration do
  up do
    create_table :reports, opts do
      primary_key :id
      
      column :board_id,     'int',      :null => false
      column :thread_id,    'int',      :null => false
      column :post_id,      'int',      :null => false
      column :created_on,   'int',      :null => false
      column :ip,           'varchar',  :null => false, :collate => collate_bin
      column :score,        'int',      :null => false
      column :category,     'varchar',  :null => false, :collate => collate_bin
      
      index :board_id
      index :thread_id
      index :post_id
      index [:ip, :post_id]
    end
  end
  
  down do
    drop_table(:reports)
  end
end
