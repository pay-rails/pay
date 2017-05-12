class Subscription < ApplicationRecord
  belongs_to :owner, class_name: Pay.billable_class

  validates :name, :processor, :processor_id, :processor_plan, :quantity, presence: true

  attribute :card_token, :string

  def on_trial?
    trial_ends_at? && Time.zone.now < trial_ends_at
  end

  def cancelled?
    ends_at?
  end

  def on_grace_period?
    cancelled? && Time.zone.now < ends_at
  end

  def active?
    ends_at.nil? || on_grace_period? || on_trial?
  end

  def cancel
    subscription = stripe_subscription.delete(at_period_end: true)
    update(ends_at: Time.at(subscription.current_period_end))
  end

  def cancel_now!
    subscription = stripe_subscription.delete
    update(ends_at: Time.at(subscription.current_period_end))
  end

  def resume
    raise StandardError, "You can only resume subscriptions within their grace period." unless on_grace_period?

    subscription = processor_subscription
    subscription.plan = processor_plan

    if on_trial?
      subscription.trial_end = trial_ends_at.to_i
    else
      subscription.trial_end = 'now'
    end

    subscription.save

    update(ends_at: nil)
    self
  end

  def processor_subscription
    Stripe::Subscription.retrieve(processor_id)
  end
end
