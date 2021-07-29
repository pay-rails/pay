class CreatePayCustomers < ActiveRecord::Migration[4.2]
  def change
    create_table :pay_customers do |t|
      t.belongs_to :owner, polymorphic: true
      t.string :processor
      t.string :processor_id
      t.boolean :default
      t.public_send Pay::Adapter.json_column_type, :pay_data

      t.timestamps
    end

    add_index :pay_customers, [:owner_type, :owner_id, :processor]
  end
end
