# frozen_string_literal: true

class AddPayMerchantTo<%= table_name.camelize %> < ActiveRecord::Migration<%= migration_version %>
  def change
    add_column table_name, :merchant_processor, :string

    # We may already have the pay_data column if a Pay::Billable object is also a Pay::Merchant
    unless ActiveRecord::Base.connection.column_exists?(table_name, :pay_data)
      add_column :<%= table_name %>, :pay_data, Pay::Adapter.json_column_type
    end
  end
end
