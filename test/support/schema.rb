# rubocop:disable BlockLength
ActiveRecord::Schema.define do
  self.verbose = false

  create_table :users, force: true do |t|
    t.string :email
    t.string :processor
    t.string :processor_id
    t.string :card_brand
    t.string :card_last4
    t.string :card_exp_month
    t.string :card_exp_year
    t.datetime :trial_ends_at
    t.text :extra_billing_info
    t.timestamps
  end

  create_table :subscriptions, force: true do |t|
    t.integer :owner_id, null: false
    t.string :name, null: false
    t.string :processor, null: false
    t.string :processor_id, null: false
    t.string :processor_plan, null: false
    t.integer :quantity, default: 1, null: false
    t.datetime :trial_ends_at
    t.datetime :ends_at
    t.timestamps
  end

  create_table :charges do |t|
    t.references :owner
    t.string :processor, null: false
    t.string :processor_id, null: false
    t.integer :amount, null: false
    t.integer :amount_refunded
    t.string :card_type
    t.string :card_last4
    t.string :card_exp_month
    t.string :card_exp_year

    t.timestamps
  end
end
