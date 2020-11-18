# This migration comes from pay (originally 20190816015720)
class AddStatusToPaySubscriptions < ActiveRecord::Migration[4.2]
  def self.up
    add_column :pay_subscriptions, :status, :string

    # Any existing subscriptions should be marked as 'active'
    # This won't actually make them active if their ends_at column is expired
    Pay::Subscription.reset_column_information
    Pay::Subscription.update_all(status: :active)
  end

  def self.down
    remove_column :pay_subscriptions, :status
  end
end
