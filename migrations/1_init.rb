opts = {
  engine: 'InnoDB',
  charset: 'utf8',
  collate: 'utf8_general_ci'
}

case DB.database_type
when :mysql
  collate_bin = 'ascii_bin'
  type_ip = 'varbinary(16)'
when :sqlite
  collate_bin = 'binary'
  type_ip = 'varbinary(16)'
when :postgres
  collate_bin = nil
  type_ip = 'bytea'
else
  collate_bin = nil
  type_ip = 'varbinary(16)'
end

Sequel.migration do
  up do
    create_table :boards, opts do
      primary_key :id
      
      column :slug,         'varchar',  :null => false
      column :title,        'varchar',  :null => false
      column :created_on,   'int',      :null => false
      column :thread_count, 'int',      :null => false, :default => 0
      column :config,       'text'
      
      index :slug, :unique => true
    end
    
    create_table :threads, opts do
      primary_key :id
      
      column :board_id,     'int',      :null => false
      column :num,          'int',      :null => false
      column :created_on,   'int',      :null => false
      column :updated_on,   'int',      :null => false
      column :title,        'varchar',  :null => false
      column :post_count,   'int',      :null => false, :default => 1
      
      index [:board_id, :num], :unique => true
      index :updated_on
    end
    
    create_table :posts, opts do
      primary_key :id
      
      column :board_id,   'int',      :null => false
      column :thread_id,  'int',      :null => false
      column :num,        'int',      :null => false, :default => 1
      column :created_on, 'int',      :null => false
      column :author,     'varchar'
      column :tripcode,   'varchar'
      column :ip,         'varchar',  :null => false, :collate => collate_bin
      column :comment,    'text'
      column :file_hash,  'varchar',  :collate => collate_bin
      column :meta,       'text'
      
      index :board_id
      index :thread_id
      index [:thread_id, :num]
      index :ip
      index :file_hash
    end
    
    create_table :users, opts do
      primary_key :id
      
      column :username,   'varchar',  :null => false, :collate => collate_bin
      column :password,   'varchar',  :null => false, :collate => collate_bin
      column :level,      'smallint', :null => false, :default => 0
      column :created_on, 'int',      :null => false
      
      index :username, :unique => true
    end
    
    create_table :sessions, opts do
      primary_key :id
      
      column :sid,        'varchar',  :null => false, :collate => collate_bin
      column :user_id,    'int',      :null => false
      column :ip,         'varchar',  :null => false, :collate => collate_bin
      column :created_on, 'int',      :null => false
      column :updated_on, 'int',      :null => false
      
      index :sid, :unique => true
    end
    
    create_table :auth_fails, opts do
      primary_key :id
      
      column :ip,         'varchar',  :null => false, :collate => collate_bin
      column :created_on, 'int',      :null => false
      
      index :ip
      index :created_on
    end
    
    create_table :bans, opts do
      primary_key :id
      
      column :ip,         type_ip,    :null => false
      column :active,     'boolean',  :null => false, :default => true
      column :created_on, 'int',      :null => false
      column :expires_on, 'int'
      column :duration,   'int'
      column :reason,     'text',     :null => false
      column :info,       'text'
      column :post,       'text'
      column :created_by, 'int',      :null => false
      column :updated_by, 'int'
      
      index [:ip, :active]
      index :expires_on
      index :created_by
    end
  end
end
