class CreatePayPaymentMethods < ActiveRecord::Migration[5.2]
  def change
    create_table :pay_payment_methods do |t|
      t.belongs_to :customer, index: true, foreign_key: {to_table: :pay_customers}
      t.string :processor_id
      t.boolean :default
      t.string :type
      t.public_send Pay::Adapter.json_column_type, :data

      t.timestamps
    end

    add_index :pay_payment_methods, [:customer_id, :processor_id], unique: true
  end
end
