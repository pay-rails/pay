class AddFieldsToUsers < ActiveRecord::Migration[4.2]
  def change
    unless ActiveRecord::Base.connection.table_exists?(Pay.billable_table)
      create_table Pay.billable_table.to_sym
    end

    add_column Pay.billable_table, :processor, :string
    add_column Pay.billable_table, :processor_id, :string
    add_column Pay.billable_table, :card_token, :string
    add_column Pay.billable_table, :card_brand, :string
    add_column Pay.billable_table, :card_last4, :string
    add_column Pay.billable_table, :card_exp_month, :string
    add_column Pay.billable_table, :card_exp_year, :string
  end
end
