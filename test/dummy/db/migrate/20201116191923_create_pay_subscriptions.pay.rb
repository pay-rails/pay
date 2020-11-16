# This migration comes from pay (originally 20170205020145)
class CreatePaySubscriptions < ActiveRecord::Migration[4.2]
  def change
    create_table :pay_subscriptions do |t|
      # Some Billable objects use string as ID, add `type: :string` if needed
      t.references :owner, polymorphic: true
      t.string :name, null: false
      t.string :processor, null: false
      t.string :processor_id, null: false
      t.string :processor_plan, null: false
      t.integer :quantity, default: 1, null: false
      t.datetime :trial_ends_at
      t.datetime :ends_at

      t.timestamps
    end
  end
end
