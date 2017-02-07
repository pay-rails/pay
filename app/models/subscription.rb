class Subscription < ActiveRecord::Base
  belongs_to :owner, class_name: Pay.billable_class
  validates :name, :processor, :processor_id, :processor_plan, :quantity, presence: true

  def active?
    ends_at.nil? || on_grace_period? || on_trial?
  end

  def on_grace_period?
    if ends_at?
      Time.zone.now < ends_at
    else
      false
    end
  end

  def on_trial?
    if trial_ends_at?
      Time.zone.now < trial_ends_at
    else
      false
    end
  end
end
