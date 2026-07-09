# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_01_01_000003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "import_errors", force: :cascade do |t|
    t.bigint "import_id", null: false
    t.integer "row_number", null: false
    t.string "message", null: false
    t.text "raw_data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["import_id", "row_number"], name: "index_import_errors_on_import_id_and_row_number", unique: true
    t.index ["import_id"], name: "index_import_errors_on_import_id"
  end

  create_table "imported_contacts", force: :cascade do |t|
    t.bigint "import_id", null: false
    t.integer "row_number", null: false
    t.string "name", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["import_id", "row_number"], name: "index_imported_contacts_on_import_id_and_row_number", unique: true
    t.index ["import_id"], name: "index_imported_contacts_on_import_id"
  end

  create_table "imports", force: :cascade do |t|
    t.string "filename", null: false
    t.string "status", default: "pending", null: false
    t.integer "total_rows", default: 0, null: false
    t.integer "processed_rows", default: 0, null: false
    t.integer "failed_rows", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_imports_on_status"
  end

  add_foreign_key "import_errors", "imports"
  add_foreign_key "imported_contacts", "imports"
end
