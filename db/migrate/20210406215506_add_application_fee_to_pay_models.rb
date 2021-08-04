class AddApplicationFeeToPayModels < ActiveRecord::Migration[4.2]
  def change
    add_column :pay_charges, :application_fee_amount, :integer
    add_column :pay_subscriptions, :application_fee_percent, :decimal, precision: 8, scale: 2
    add_column :pay_charges, :pay_subscription_id, :integer
  end
end
