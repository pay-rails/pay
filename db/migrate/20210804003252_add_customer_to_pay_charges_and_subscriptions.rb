class AddCustomerToPayChargesAndSubscriptions < ActiveRecord::Migration[6.0]
  def change
    add_column :pay_subscriptions, :metadata, Pay::Adapter.json_column_type
    add_column :pay_charges, :metadata, Pay::Adapter.json_column_type

    add_reference :pay_charges, :customer, index: true, foreign_key: {to_table: :pay_customers}
    add_reference :pay_subscriptions, :customer, index: true, foreign_key: {to_table: :pay_customers}

    remove_index :pay_charges, [:processor, :processor_id]
    remove_index :pay_subscriptions, [:processor, :processor_id]

    add_index :pay_charges, [:customer_id, :processor_id], unique: true
    add_index :pay_subscriptions, [:customer_id, :processor_id], unique: true
  end
end
