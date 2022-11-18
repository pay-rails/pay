class AddPauseDetailsToPaySubscriptions < ActiveRecord::Migration[6.0]
  def change
    add_column :pay_subscriptions, :metered, :boolean
    add_column :pay_subscriptions, :pause_behavior, :string
    add_column :pay_subscriptions, :pause_starts_at, :datetime
    add_column :pay_subscriptions, :pause_resumes_at, :datetime

    add_index :pay_subscriptions, :metered
    add_index :pay_subscriptions, :pause_starts_at

    Pay::Subscription.find_each do |pay_subscription|
      pay_subscription.update(
        metered: pay_subscription.data&.dig("metered"),
        pause_behavior: pay_subscription.data&.dig("pause_behavior"),
        pause_starts_at: pay_subscription.data&.dig("paddle_paused_from"),
        pause_resumes_at: pay_subscription.data&.dig("pause_resumes_at")
      )
    end
  end
end
