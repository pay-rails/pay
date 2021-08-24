class Pay::Customer < Pay::ApplicationRecord
  belongs_to :owner, polymorphic: true
  has_many :charges, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :payment_methods, dependent: :destroy
  has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::PaymentMethod"

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  validates :processor_id, allow_blank: true, uniqueness: {scope: :processor, case_sensitive: true}

  attribute :plan, :string
  attribute :quantity, :integer
  attribute :payment_method_token, :string

  # Account(s) for marketplace payments
  store_accessor :data, :stripe_account
  store_accessor :data, :braintree_account

  delegate :email, to: :owner
  delegate_missing_to :pay_processor

  def self.processor_for(name)
    "Pay::#{name.to_s.classify}::Billable".constantize
  end

  def pay_processor
    @pay_processor ||= self.class.processor_for(processor).new(self)
  end

  def update_payment_method(payment_method_id)
    add_payment_method(payment_method_id, default: true)
  end

  def subscription(name: Pay.default_product_name)
    subscriptions.loaded? ? subscriptions.reverse.detect { |s| s.name == name } : subscriptions.for_name(name).last
  end

  def subscribed?(name: Pay.default_product_name, processor_plan: nil)
    subscription = subscription(name: name)

    return false if subscription.nil?
    return subscription.active? if processor_plan.nil?

    subscription.active? && subscription.processor_plan == processor_plan
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

  def has_incomplete_payment?(name: Pay.default_product_name)
    subscription(name: name)&.has_incomplete_payment?
  end

  def customer_name
    [owner.try(:first_name), owner.try(:last_name)].compact.join(" ")
  end

  def active?
    deleted_at.nil?
  end

  def deleted?
    deleted_at.present?
  end

  %w[stripe braintree paddle fake_processor].each do |processor_name|
    define_method "#{processor_name}?" do
      processor == processor_name
    end
  end
end
