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

ActiveRecord::Schema[7.1].define(version: 2026_02_21_105500) do
  create_table "audit_logs", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "user_id"
    t.string "event", null: false
    t.integer "from_status"
    t.integer "to_status"
    t.string "reason"
    t.text "metadata", size: :long, collation: "utf8mb4_bin"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "created_at"], name: "index_audit_logs_on_order_id_and_created_at"
    t.index ["order_id"], name: "index_audit_logs_on_order_id"
    t.index ["user_id", "created_at"], name: "index_audit_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
    t.check_constraint "json_valid(`metadata`)", name: "metadata"
  end

  create_table "combo_items", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "combo_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["combo_id", "product_id"], name: "index_combo_items_on_combo_id_and_product_id", unique: true
    t.index ["combo_id"], name: "index_combo_items_on_combo_id"
    t.index ["product_id"], name: "index_combo_items_on_product_id"
    t.check_constraint "`quantity` > 0", name: "chk_combo_items_quantity"
  end

  create_table "combos", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.integer "price_cents", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_combos_on_active"
    t.check_constraint "`price_cents` >= 0", name: "chk_combos_price_cents"
  end

  create_table "order_items", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id"
    t.bigint "combo_id"
    t.integer "quantity", default: 1, null: false
    t.integer "unit_price_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "notes"
    t.index ["combo_id"], name: "index_order_items_on_combo_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
    t.check_constraint "`quantity` > 0", name: "chk_order_items_quantity"
    t.check_constraint "`total_cents` >= 0", name: "chk_order_items_total"
    t.check_constraint "`unit_price_cents` >= 0", name: "chk_order_items_unit_price"
  end

  create_table "orders", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "customer_id"
    t.integer "status", default: 0, null: false
    t.integer "subtotal_cents", default: 0, null: false
    t.integer "discount_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.integer "eta_minutes"
    t.integer "queue_position"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "order_type", default: 0, null: false
    t.string "table_number"
    t.string "delivery_address"
    t.string "service_token"
    t.datetime "received_at"
    t.datetime "started_at"
    t.datetime "ready_at"
    t.datetime "delivered_at"
    t.datetime "canceled_at"
    t.index ["customer_id", "created_at"], name: "index_orders_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["order_type", "status", "created_at"], name: "idx_orders_type_status_created"
    t.index ["order_type"], name: "index_orders_on_order_type"
    t.index ["service_token"], name: "index_orders_on_service_token", unique: true
    t.index ["status", "created_at"], name: "index_orders_on_status_and_created_at"
    t.index ["table_number"], name: "index_orders_on_table_number"
    t.check_constraint "`discount_cents` >= 0", name: "chk_orders_discount_cents"
    t.check_constraint "`status` in (0,1,2,3,4,5,6)", name: "chk_orders_status"
    t.check_constraint "`subtotal_cents` >= 0", name: "chk_orders_subtotal_cents"
    t.check_constraint "`total_cents` >= 0", name: "chk_orders_total_cents"
  end

  create_table "payments", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.integer "status", default: 0, null: false
    t.integer "amount_cents", default: 0, null: false
    t.string "provider", default: "mock", null: false
    t.string "provider_reference"
    t.string "provider_event_id"
    t.datetime "approved_at"
    t.string "refused_reason"
    t.text "raw_payload", size: :long, collation: "utf8mb4_bin"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_payments_on_order_id"
    t.index ["provider_event_id"], name: "index_payments_on_provider_event_id", unique: true
    t.check_constraint "`amount_cents` >= 0", name: "chk_payments_amount"
    t.check_constraint "`status` in (0,1,2,3)", name: "chk_payments_status"
    t.check_constraint "json_valid(`raw_payload`)", name: "raw_payload"
  end

  create_table "products", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.integer "price_cents", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.integer "prep_minutes", default: 10, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_products_on_active"
    t.check_constraint "`prep_minutes` > 0", name: "chk_products_prep_minutes"
    t.check_constraint "`price_cents` >= 0", name: "chk_products_price_cents"
  end

  create_table "promotions", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.decimal "discount_percent", precision: 5, scale: 2, default: "0.0", null: false
    t.boolean "active", default: true, null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_promotions_on_active"
    t.check_constraint "`discount_percent` >= 0 and `discount_percent` <= 100", name: "chk_promotions_discount_percent"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_uca1400_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.integer "role", default: 0, null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "provider"
    t.string "uid"
    t.string "avatar_url"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
    t.check_constraint "`role` in (0,1)", name: "chk_users_role"
  end

  add_foreign_key "audit_logs", "orders"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "combo_items", "combos"
  add_foreign_key "combo_items", "products"
  add_foreign_key "order_items", "combos"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "users", column: "customer_id"
  add_foreign_key "payments", "orders"
end
