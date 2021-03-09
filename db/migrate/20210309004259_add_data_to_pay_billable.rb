class AddDataToPayBillable < ActiveRecord::Migration[6.1]
  def change
    # Load all the billable models
    Rails.application.eager_load!

    Pay.billable_models.each do |model|
      add_column model.table_name, :pay_data, data_column_type
    end
  end

  def data_column_type
    case ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).first.adapter
    when "postgresql"
      :jsonb
    else
      :json
    end
  end
end
