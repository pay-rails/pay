class AddDataToPayModels < ActiveRecord::Migration[6.0]
  def change
    add_column :pay_subscriptions, :data, Pay::Adapter.json_column_type
    add_column :pay_charges, :data, Pay::Adapter.json_column_type
  end
end
