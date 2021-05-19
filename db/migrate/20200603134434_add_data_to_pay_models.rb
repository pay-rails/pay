class AddDataToPayModels < ActiveRecord::Migration[4.2]
  def change
    add_column :pay_subscriptions, :data, data_column_type
    add_column :pay_charges, :data, data_column_type
  end

  def data_column_type
    case Pay::Adapter.current_adapter
    when "postgresql"
      :jsonb
    else
      :json
    end
  end
end
