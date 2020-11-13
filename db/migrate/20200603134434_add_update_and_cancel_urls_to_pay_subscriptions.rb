class AddUpdateAndCancelUrlsToPaySubscriptions < ActiveRecord::Migration[4.2]
  def change
    add_column :pay_subscriptions, :update_url, :string
    add_column :pay_subscriptions, :cancel_url, :string
  end
end
