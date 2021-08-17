class UpgradeToPayVersion3 < ActiveRecord::Migration[6.0]
  # List of models to migrate from Pay v2 to Pay v3
  MODELS = [User, Team]

  def self.up
    # Migrate models to Pay::Customer
    MODELS.each do |klass|
      #TODO: Replace "jumpstart" processor with "fake_processor"

      klass.where.not(processor: nil).find_each do |record|
        # Migrate to Pay::Customer
        pay_customer = Pay::Customer.where(owner: record, processor: record.processor, processor_id: record.processor_id).first_or_initialize
        pay_customer.update!(
          default: true,

          # Optional: Used for Marketplace payments
          data: {
            stripe_account: record.try(:stripe_account),
            braintree_account: record.try(:braintree_account),
          }
        )

        # Associate Pay::Charges with new Pay::Customer
        Pay::Charge.where(owner_type: record.class.name, owner_id: record.id).each do |charge|
          # Since customers can switch between payment processors, we have to find or create
          customer = Pay::Customer.where(owner: record, processor: charge.processor).first_or_create!
          charge.update!(customer: customer)
        end

        # Associate Pay::Subscription with new Pay::Customer
        Pay::Subscription.where(owner_type: record.class.name, owner_id: record.id).each do |subscription|
          # Since customers can switch between payment processors, we have to find or create
          customer = Pay::Customer.where(owner: record, processor: subscription.processor).first_or_create!
          subscription.update!(customer: customer)
        end

         # Migrate to Pay::PaymentMethod
        if record.card_type?
          # Lookup default payment method via API and create them as Pay::PaymentMethods
          begin
            case pay_customer.processor
            when "braintree"
              #payment_method_id = pay_customer.customer.payment_methods.find(&:default?)
              #Pay::Braintree::PaymentMethod.sync(payment_method_id) if payment_method_id
            when "stripe"
              #payment_method_id = pay_customer.customer.invoice_settings.default_payment_method
              #Pay::Stripe::PaymentMethod.sync(payment_method_id) if payment_method_id
            end
          rescue
          end
        end
      end

      # Migrate Pay::Charge payment method details
      Pay::Charge.find_each do |charge|
        # Data column should be a hash. If we find a string instead, replace it
        charge.data = {} if charge.data.is_a?(String)

        case charge.card_type.downcase
        when "paypal"
          charge.update(payment_method_type: :paypal, brand: "PayPal", email: charge.card_last4)
        else
          charge.update(payment_method_type: :card, brand: charge.card_type, last4: charge.card_last4, exp_month: charge.card_exp_month, exp_year: charge.card_exp_year)
        end
      end

      # Migrate generic trials
      # Anyone on a generic trial gets a fake processor subscription with the same end timestamp
      klass.where("trial_ends_at >= ?", Time.current).find_each do |record|
        # Make sure we don't have any conflicts when setting fake processor as the default
        Pay::Customer.where(owner: record, default: true).update_all(default: false)

        pay_customer = Pay::Customer.where(owner: record, processor: :fake_processor, default: true).first_or_create!
        pay_customer.subscribe(
          trial_ends_at: record.trial_ends_at,
          ends_at: record.trial_ends_at,

          # Appease the null: false on processor before we remove columns
          processor: :fake_processor
        )
      end
    end

    # Drop unneeded columns
    remove_column :pay_charges, :owner_type
    remove_column :pay_charges, :owner_id
    remove_column :pay_charges, :processor
    remove_column :pay_charges, :card_type
    remove_column :pay_charges, :card_last4
    remove_column :pay_charges, :card_exp_month
    remove_column :pay_charges, :card_exp_year
    remove_column :pay_subscriptions, :owner_type
    remove_column :pay_subscriptions, :owner_id
    remove_column :pay_subscriptions, :processor

    MODELS.each do |klass|
      remove_column klass.table_name, :processor
      remove_column klass.table_name, :processor_id
      remove_column klass.table_name, :pay_data
      remove_column klass.table_name, :card_type
      remove_column klass.table_name, :card_last4
      remove_column klass.table_name, :card_exp_month
      remove_column klass.table_name, :card_exp_year
      remove_column klass.table_name, :trial_ends_at
    end
  end

  def self.down
    add_column :pay_charges, :owner_type, :string
    add_column :pay_charges, :owner_id, :integer
    add_column :pay_charges, :processor, :string
    add_column :pay_subscriptions, :owner_type, :string
    add_column :pay_subscriptions, :owner_id, :integer
    add_column :pay_subscriptions, :processor, :string

    MODELS.each do |klass|
      add_column klass.table_name, :processor, :string
      add_column klass.table_name, :processor_id, :string
      add_column klass.table_name, :pay_data, Pay::Adapter.json_column_type
      add_column klass.table_name, :card_type, :string
      add_column klass.table_name, :card_last4, :string
      add_column klass.table_name, :card_exp_month, :string
      add_column klass.table_name, :card_exp_year, :string
      add_column klass.table_name, :trial_ends_at, :datetime
    end
  end
end
