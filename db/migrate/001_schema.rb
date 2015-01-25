class Schema < ActiveRecord::Migration
  def change
    create_table :links, force: true do |t|
      t.integer :change_number, null: false
      t.integer :differential_id, null: false
      t.text :patch_set_revisions
    end
    add_index :links, :change_number, unique: true
  end
end
