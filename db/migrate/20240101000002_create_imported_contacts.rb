class CreateImportedContacts < ActiveRecord::Migration[7.1]
  def change
    create_table :imported_contacts do |t|
      t.references :import, null: false, foreign_key: true
      t.integer :row_number, null: false
      t.string :name, null: false
      t.string :email, null: false

      t.timestamps
    end

    # The idempotency key for the pipeline: a retried batch job upserts
    # against this index instead of inserting duplicates.
    add_index :imported_contacts, %i[import_id row_number], unique: true
  end
end
