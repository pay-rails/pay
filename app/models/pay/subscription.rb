module Pay
  class Subscription < Pay::ApplicationRecord
    STATUSES = %w[incomplete incomplete_expired trialing active past_due canceled unpaid paused]

    # Associations
    belongs_to :customer
    has_many :charges

    # Scopes
    scope :for_name, ->(name) { where(name: name) }
    scope :on_trial, -> { where.not(trial_ends_at: nil).where("#{table_name}.trial_ends_at > ?", Time.current) }
    scope :cancelled, -> { where.not(ends_at: nil) }
    scope :on_grace_period, -> { cancelled.where("#{table_name}.ends_at > ?", Time.current) }
    scope :active, -> { where(status: ["trialing", "active"], ends_at: nil).pause_not_started.or(on_grace_period).or(on_trial) }
    scope :paused, -> { where(status: "paused").or(where("pause_starts_at <= ?", Time.current)) }
    scope :pause_not_started, -> { where("pause_starts_at IS NULL OR pause_starts_at > ?", Time.current) }
    scope :active_or_paused, -> { active.or(paused) }
    scope :incomplete, -> { where(status: :incomplete) }
    scope :past_due, -> { where(status: :past_due) }
    scope :metered, -> { where(metered: true) }
    scope :with_active_customer, -> { joins(:customer).merge(Customer.active) }
    scope :with_deleted_customer, -> { joins(:customer).merge(Customer.deleted) }

    # Callbacks
    before_destroy :cancel_if_active

    store_accessor :data, :paddle_update_url
    store_accessor :data, :paddle_cancel_url
    store_accessor :data, :stripe_account
    store_accessor :data, :subscription_items

    attribute :prorate, :boolean, default: true

    # Validations
    validates :name, presence: true
    validates :processor_id, presence: true, uniqueness: {scope: :customer_id, case_sensitive: true}
    validates :processor_plan, presence: true
    validates :quantity, presence: true, numericality: {only_integer: true, greater_than_or_equal_to: 0}
    validates :status, presence: true

    delegate_missing_to :payment_processor

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

    def sync!(**options)
      self.class.pay_processor_for(customer.processor).sync(processor_id, **options)
      reload
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

    def has_trial?
      trial_ends_at?
    end

    def on_trial?
      trial_ends_at? && trial_ends_at.after?(Time.current)
    end

    def trial_ended?
      trial_ends_at? && trial_ends_at.before?(Time.current)
    end

    def canceled?
      ends_at?
    end

    def cancelled?
      canceled?
    end

    def on_grace_period?
      (ends_at? && Time.current < ends_at) ||
        ((status == "paused" || pause_behavior == "void") && will_pause?)
    end

    def will_pause?
      pause_starts_at? && Time.current < pause_starts_at
    end

    def pause_active?
      (status == "paused" || pause_behavior == "void") && (pause_starts_at.nil? || pause_starts_at >= Time.current)
    end

    def active?
      ["trialing", "active"].include?(status) && (!(canceled? || paused?) || on_trial? || on_grace_period?)
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

    def change_quantity(quantity, **options)
      payment_processor.change_quantity(quantity, **options)
      update(quantity: quantity)
    end

    def resume
      payment_processor.resume
      update(ends_at: nil, status: :active)
      self
    end

    def swap(plan, **options)
      raise ArgumentError, "plan must be a string. Got `#{plan.inspect}` instead." unless plan.is_a?(String)
      payment_processor.swap(plan, **options)
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
