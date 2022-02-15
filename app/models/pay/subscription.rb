module Pay
  class Subscription < Pay::ApplicationRecord
    STATUSES = %w[incomplete incomplete_expired trialing active past_due canceled unpaid paused]

    # Associations
    belongs_to :customer
    has_many :charges
    has_many :subscription_items, class_name: "Pay::SubscriptionItem", foreign_key: :pay_subscription_id

    # Scopes
    scope :for_name, ->(name) { where(name: name) }
    scope :on_trial, -> { where.not(trial_ends_at: nil).where("#{table_name}.trial_ends_at > ?", Time.zone.now) }
    scope :cancelled, -> { where.not(ends_at: nil) }
    scope :on_grace_period, -> { cancelled.where("#{table_name}.ends_at > ?", Time.zone.now) }
    scope :active, -> { where(status: ["trialing", "active"], ends_at: nil).or(on_grace_period).or(on_trial) }
    scope :incomplete, -> { where(status: :incomplete) }
    scope :past_due, -> { where(status: :past_due) }
    scope :with_active_customer, -> { joins(:customer).merge(Customer.active) }
    scope :with_deleted_customer, -> { joins(:customer).merge(Customer.deleted) }

    # Callbacks
    before_destroy :cancel_if_active

    store_accessor :data, :paddle_update_url
    store_accessor :data, :paddle_cancel_url
    store_accessor :data, :paddle_paused_from
    store_accessor :data, :stripe_account

    attribute :prorate, :boolean, default: true

    # Validations
    validates :name, presence: true
    validates :processor_id, presence: true, uniqueness: {scope: :customer_id, case_sensitive: true}
    validates :processor_plan, presence: true, allow_nil: true
    validates :quantity, presence: true, numericality: {
      only_integer: true,
      greater_than_or_equal_to: 1,
      allow_nil: true
    }

    validates :status, presence: true

    accepts_nested_attributes_for :subscription_items, allow_destroy: true

    delegate :on_grace_period?,
      :paused?,
      :pause,
      :cancel,
      :cancel_now!,
      to: :payment_processor

    # Helper methods for payment processors
    %w[braintree stripe paddle fake_processor].each do |processor_name|
      define_method "#{processor_name}?" do
        customer.processor == processor_name
      end

      scope processor_name, -> { joins(:customer).where(pay_customers: {processor: processor_name}) }
    end

    def self.find_by_processor_and_id(processor, processor_id)
      joins(:customer).find_by(processor_id: processor_id, pay_customers: {processor: processor})
    end

    def self.pay_processor_for(name)
      "Pay::#{name.to_s.classify}::Subscription".constantize
    end

    def payment_processor
      @payment_processor ||= self.class.pay_processor_for(customer.processor).new(self)
    end

    def no_prorate
      self.prorate = false
    end

    def skip_trial
      self.trial_ends_at = nil
    end

    def generic_trial?
      fake_processor? && trial_ends_at?
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

    def change_quantity(quantity)
      payment_processor.change_quantity(quantity)
      update(quantity: quantity)
    end

    def resume
      payment_processor.resume
      update(ends_at: nil, status: :active)
      self
    end

    def swap(plan)
      raise ArgumentError, "plan must be a string. Got `#{plan.inspect}` instead." unless plan.is_a?(String)
      payment_processor.swap(plan)
      update(processor_plan: plan, ends_at: nil, status: :active)
    end

    def swap_and_invoice(plan)
      swap(plan)
      owner.invoice!(subscription_id: processor_id)
    end

    def processor_subscription(**options)
      payment_processor.subscription(**options)
    end

    def latest_payment
      processor_subscription(expand: ["latest_invoice.payment_intent"]).latest_invoice.payment_intent
    end

    def paddle_paused_from
      if (timestamp = super)
        Time.zone.parse(timestamp)
      end
    end

    private

    def cancel_if_active
      if active?
        cancel_now!
      end
    rescue => e
      Rails.logger.info "[Pay] Unable to automatically cancel subscription `#{customer.processor} #{id}`: #{e.message}"
    end
  end
end
