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

ActiveRecord::Schema[7.0].define(version: 2021_09_03_224317) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "monuments", force: :cascade do |t|
    t.string "item"
    t.string "wlmid"
    t.decimal "latitude"
    t.decimal "longitude"
    t.string "itemlabel"
    t.string "image"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "itemdescription"
    t.string "wikipedia"
    t.boolean "with_photos"
    t.integer "photos_count"
    t.string "commons"
    t.string "uploadurl"
    t.string "regione"
    t.string "nonwlmuploadurl"
    t.boolean "hidden", default: false
    t.datetime "enddate", precision: nil
    t.boolean "duplicate", default: false
    t.string "city"
    t.string "address"
    t.boolean "tree", default: false
    t.boolean "noupload", default: false
    t.date "year"
    t.string "allphotos"
    t.string "city_item"
    t.integer "commonsphotos"
    t.index ["item"], name: "index_monuments_on_item", unique: true
  end

  create_table "nophotos", force: :cascade do |t|
    t.integer "count"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "monuments"
    t.integer "with_commons"
    t.integer "with_image"
    t.integer "nowlm"
    t.string "regione"
    t.integer "cities"
    t.integer "cities_with_trees"
  end

  create_table "towns", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "item"
    t.string "disambiguation"
    t.string "visible_name"
    t.string "search_name"
    t.decimal "latitude"
    t.decimal "longitude"
    t.string "english_name"
    t.index ["name", "disambiguation"], name: "index_towns_on_name_and_disambiguation", unique: true
  end

end
