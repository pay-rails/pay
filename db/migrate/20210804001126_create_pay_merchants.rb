class CreatePayMerchants < ActiveRecord::Migration[5.0]
  def change
    create_table :pay_merchants do |t|
      t.belongs_to :owner, polymorphic: true
      t.string :processor
      t.string :processor_id
      t.boolean :default
      t.public_send Pay::Adapter.json_column_type, :data

      t.timestamps
    end

    add_index :pay_merchants, [:owner_type, :owner_id, :processor]
  end
end
