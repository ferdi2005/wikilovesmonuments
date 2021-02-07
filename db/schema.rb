# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_02_07_000655) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "monuments", force: :cascade do |t|
    t.string "item"
    t.string "wlmid"
    t.decimal "latitude"
    t.decimal "longitude"
    t.string "itemlabel"
    t.string "image"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "itemdescription"
    t.string "wikipedia"
    t.boolean "with_photos"
    t.integer "photos_count"
    t.string "commons"
    t.string "uploadurl"
    t.string "regione"
    t.string "nonwlmuploadurl"
    t.boolean "hidden"
    t.datetime "enddate"
    t.boolean "duplicate", default: false
    t.string "city"
  end

  create_table "nophotos", force: :cascade do |t|
    t.integer "count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "monuments"
    t.integer "with_commons"
    t.integer "with_image"
    t.integer "nowlm"
    t.string "regione"
  end

end
