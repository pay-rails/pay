module Pay
  class Customer < Pay::ApplicationRecord
    belongs_to :owner, polymorphic: true
    has_many :charges, dependent: :destroy
    has_many :subscriptions, dependent: :destroy
    has_many :payment_methods, dependent: :destroy
    has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::PaymentMethod"

    scope :active, -> { where(deleted_at: nil) }
    scope :deleted, -> { where.not(deleted_at: nil) }
    scope :not_fake_processor, -> { where.not(processor: :fake_processor) }

    validates :processor, presence: true
    validates :processor_id, allow_blank: true, uniqueness: {scope: :processor, case_sensitive: true}

    attribute :payment_method_token, :string

    # Account(s) for marketplace payments
    store_accessor :data, :braintree_account

    # Stripe invoice credit balance is a Hash-like object { "usd" => 1234 }
    store_accessor :data, :invoice_credit_balance
    store_accessor :data, :currency

    delegate :email, to: :owner
    delegate_missing_to :pay_processor

    %w[stripe braintree paddle_billing paddle_classic lemon_squeezy fake_processor].each do |processor_name|
      scope processor_name, -> { where(processor: processor_name) }

      define_method :"#{processor_name}?" do
        processor == processor_name
      end
    end

    def self.pay_processor_for(name)
      "Pay::#{name.to_s.classify}::Billable".constantize
    end

    def pay_processor
      return if processor.blank?
      @pay_processor ||= self.class.pay_processor_for(processor).new(self)
    end

    def update_payment_method(payment_method_id)
      add_payment_method(payment_method_id, default: true)
    end

    def subscription(name: Pay.default_product_name)
      subscriptions.order(created_at: :desc).for_name(name).first
    end

    def subscribed?(name: Pay.default_product_name, processor_plan: nil)
      query = {name: name, processor_plan: processor_plan}.compact
      subscriptions.active.where(query).exists?
    end

    def on_trial?(name: Pay.default_product_name, plan: nil)
      sub = subscription(name: name)
      return sub&.on_trial? if plan.nil?

      sub&.on_trial? && sub.processor_plan == plan
    end

    def on_trial_or_subscribed?(name: Pay.default_product_name, processor_plan: nil)
      on_trial?(name: name, plan: processor_plan) ||
        subscribed?(name: name, processor_plan: processor_plan)
    end

    def has_incomplete_payment?
      subscriptions.active.incomplete.any?
    end

    def customer_name
      return owner.pay_customer_name if owner.respond_to?(:pay_customer_name) && owner.pay_customer_name.present?
      owner.respond_to?(:name) ? owner.name : [owner.try(:first_name), owner.try(:last_name)].compact.join(" ")
    end

    def active?
      deleted_at.nil?
    end

    def deleted?
      deleted_at.present?
    end

    def on_generic_trial?
      return false unless fake_processor?

      subscription = subscriptions.active.last
      return false unless subscription

      # If these match, consider it a generic trial
      subscription.trial_ends_at == subscription.ends_at
    end

    # Attempts to pay all past_due subscription invoices to bring them back to active state
    # Pass in `statuses: []` if you would like to only include specific subscription statuses
    def retry_past_due_subscriptions!(status: [:past_due])
      subscriptions.where(status: Array.wrap(status)).each(&:pay_open_invoices)
    end
  end
end
