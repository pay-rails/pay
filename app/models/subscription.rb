class Subscription < ApplicationRecord
  # Associations
  belongs_to :owner, class_name: Pay.billable_class, foreign_key: :owner_id

  # Validations
  validates :name, presence: true
  validates :processor, presence: true
  validates :processor_id, presence: true
  validates :processor_plan, presence: true
  validates :quantity, presence: true

  # Scopes
  scope :for_name, ->(name) { where(name: name) }

  attribute :prorate, :boolean, default: true

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
    subscription = processor_subscription.delete(at_period_end: true)
    update(ends_at: Time.at(subscription.current_period_end))
  end

  def cancel_now!
    subscription = processor_subscription.delete
    update(ends_at: Time.at(subscription.current_period_end))
  end

  def resume
    unless on_grace_period?
      raise StandardError,
            'You can only resume subscriptions within their grace period.'
    end

    subscription = processor_subscription
    subscription.plan = processor_plan
    subscription.trial_end = on_trial? ? trial_ends_at.to_i : 'now'
    subscription.cancel_at_period_end = false
    subscription.save

    update(ends_at: nil)
    self
  end

  def no_prorate
    self.prorate = false
  end

  def skip_trial
    self.trial_ends_at = nil
  end

  def swap(plan)
    subscription = processor_subscription
    subscription.plan = plan
    subscription.prorate = prorate
    subscription.trial_end = on_trial? ? trial_ends_at : 'now'
    subscription.quantity = quantity if quantity?
    subscription.save
    update(processor_plan: plan, ends_at: nil)
  end

  def processor_subscription
    owner.processor_subscription(processor_id)
  end
end
