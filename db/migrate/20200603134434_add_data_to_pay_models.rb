class AddDataToPayModels < ActiveRecord::Migration[4.2]
  def change
    add_column :pay_subscriptions, :data, data_column_type
    add_column :pay_charges, :data, data_column_type
  end

  def data_column_type
    case ActiveRecord::Base.configurations.default_hash.dig("adapter")
    when "mysql2"
      :json
    when "postgresql"
      :jsonb
    else
      :text
    end
  end
end
