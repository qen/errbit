class CreateBacktraceLines < ActiveRecord::Migration
  def change
    create_table :backtrace_lines do |t|
      t.integer :backtrace_id
      t.integer :number
      t.string :file
      t.string :method

      t.timestamps
    end

    add_index :backtrace_lines, :backtrace_id
  end
end
