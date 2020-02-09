module Pay
  class Subscription < ApplicationRecord
    self.table_name = Pay.subscription_table

    STATUSES = %w[incomplete incomplete_expired trialing active past_due canceled unpaid]

    # Associations
    belongs_to :owner, class_name: Pay.billable_class, foreign_key: :owner_id

    # Validations
    validates :name, presence: true
    validates :processor, presence: true
    validates :processor_id, presence: true
    validates :processor_plan, presence: true
    validates :quantity, presence: true
    validates :status, presence: true

    # Scopes
    scope :for_name, ->(name) { where(name: name) }
    scope :on_trial, -> { where.not(trial_ends_at: nil).where("trial_ends_at > ?", Time.zone.now) }
    scope :cancelled, -> { where.not(ends_at: nil) }
    scope :on_grace_period, -> { cancelled.where("ends_at > ?", Time.zone.now) }
    scope :active, -> { where(ends_at: nil).or(on_grace_period).or(on_trial) }
    scope :incomplete, -> { where(status: :incomplete) }
    scope :past_due, -> { where(status: :past_due) }

    attribute :prorate, :boolean, default: true

    def no_prorate
      self.prorate = false
    end

    def skip_trial
      self.trial_ends_at = nil
    end

    def on_trial?
      trial_ends_at? && Time.zone.now < trial_ends_at
    end

    def canceled?
      ends_at?
    end

    def cancelled?
      canceled?
    end

    def on_grace_period?
      canceled? && Time.zone.now < ends_at
    end

    def active?
      ["trialing", "active"].include?(status) && (ends_at.nil? || on_grace_period? || on_trial?)
    end

    def past_due?
      status == "past_due"
    end

    def incomplete?
      status == "incomplete"
    end

    def has_incomplete_payment?
      past_due? || incomplete?
    end

    def cancel
      send("#{processor}_cancel")
    end

    def cancel_now!
      send("#{processor}_cancel_now!")
    end

    def resume
      unless on_grace_period?
        raise StandardError,
          "You can only resume subscriptions within their grace period."
      end

      send("#{processor}_resume")

      update(ends_at: nil)
      self
    end

    def swap(plan)
      send("#{processor}_swap", plan)
      update(processor_plan: plan, ends_at: nil)
    end

    def swap_and_invoice(plan)
      swap(plan)
      owner.invoice!(subscription_id: processor_id)
    end

    def processor_subscription(options = {})
      owner.processor_subscription(processor_id, options)
    end

    def latest_payment
      return unless stripe?
      processor_subscription(expand: ["latest_invoice.payment_intent"]).latest_invoice.payment_intent
    end
  end
end
