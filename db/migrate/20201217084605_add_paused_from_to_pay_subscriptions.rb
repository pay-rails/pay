class AddPausedFromToPaySubscriptions < ActiveRecord::Migration[4.2]
  def change
    add_column :pay_subscriptions, :paused_from, :datetime
  end
end
