class CreateErrs < ActiveRecord::Migration
  def change
    create_table :errs do |t|
      t.integer :problem_id
      t.string :error_class
      t.string :component
      t.string :action
      t.string :environment
      t.string :fingerprint

      t.timestamps
    end

    add_index :errs, :problem_id
    add_index :errs, :error_class
    add_index :errs, :fingerprint
  end
end
