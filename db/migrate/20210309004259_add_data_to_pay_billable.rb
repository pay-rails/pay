class AddDataToPayBillable < ActiveRecord::Migration[4.2]
  def change
    # Load all the billable models
    Rails.application.eager_load!

    Pay.billable_models.each do |model|
      add_column model.table_name, :pay_data, data_column_type
    end
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
