class CreateImportErrors < ActiveRecord::Migration[7.1]
  def change
    create_table :import_errors do |t|
      t.references :import, null: false, foreign_key: true
      t.integer :row_number, null: false
      t.string :message, null: false
      t.text :raw_data

      t.timestamps
    end

    add_index :import_errors, %i[import_id row_number], unique: true
  end
end
