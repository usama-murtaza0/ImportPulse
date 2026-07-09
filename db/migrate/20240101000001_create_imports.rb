class CreateImports < ActiveRecord::Migration[7.1]
  def change
    create_table :imports do |t|
      t.string :filename, null: false
      t.string :status, null: false, default: "pending"
      t.integer :total_rows, null: false, default: 0
      t.integer :processed_rows, null: false, default: 0
      t.integer :failed_rows, null: false, default: 0

      t.timestamps
    end

    add_index :imports, :status
  end
end
