class SetupActsAsModerateable < ActiveRecord::Migration
  def self.up
    # remove the old stuff
    remove_column :pages, :vetted
    remove_column :pages, :yuck_count
    
    remove_column :posts, :vetted
    remove_column :posts, :yuck_count
    
    add_column :posts, :inappropriate, :integer, :default => 0
    add_column :pages, :inappropriate, :integer, :default => 0
  end
  
  def self.down
    add_column :pages, :vetted, :boolean, :default => false
    add_column :pages, :yuck_count, :integer, :default => 0
    
    add_column :posts, :vetted, :boolean, :default => false
    add_column :posts, :yuck_count, :integer, :default => 0
    
    remove_column :posts, :inappropriate
    remove_column :pages, :inappropriate
  end
end

