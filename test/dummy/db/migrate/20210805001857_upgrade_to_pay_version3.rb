class UpgradeToPayVersion3 < ActiveRecord::Migration[5.2]
  # List of models to migrate from Pay v2 to Pay v3
  MODELS = [User, Team]

  def change
    # Migrate models to Pay::Customer
    MODELS.each do |klass|
      klass.where.not(processor: nil).find_each do |record|
        # Migrate to Pay::Customer
        pay_customer = record.pay_customers.create!(
          processor: record.processor,
          processor_id: record.processor_id,
          default: true,
          data: {
            stripe_account: record.stripe_account,
            braintree_account: record.braintree_account,
          }
        )

        # Associate Pay::Charges with Pay::Customer
        Pay::Charge.where(owner_type: record.class, owner_id: record.id).each do |charge|
          customer = record.pay_customers.where(processor: charge.processor).first_or_create!
          charge.update!(customer: customer)
        end

        # Associate Pay::Subscription with Pay::Customer
        Pay::Subscription.where(owner_type: record.class, owner_id: record.id).each do |subscription|
          customer = record.pay_customers.where(processor: subscription.processor).first_or_create!
          subscription.update!(customer: customer)
        end

         # Migrate to Pay::PaymentMethod
        if record.card_type?
          kind = (record.card_type == "PayPal" ? "paypal" : "card")

          attrs = { kind: kind }

          if kind == "paypal"
            attrs[:email] = record.card_last4
          else
            attrs.merge(last4: record.card_last4, type: record.card_type, exp_month: record.exp_month, exp_year: record.exp_year)
          end

          pay_customer.payment_methods.create!(attrs)
        end
      end

      # Migrate generic trials
      # Anyone on a generic trial gets a fake processor subscription with the same end timestamp
      klass.where("trial_ends_at >= ?", Time.current).find_each do |record|
        record.set_payment_processor :fake_processor, allow_fake: true
        record.payment_processor.subscriptions.create(
          trial_ends_at: record.trial_ends_at,
          ends_at: trial_ends_at
        )
      end
    end

    # Drop unneeded columns
    remove_column :pay_charges, :owner_type
    remove_column :pay_charges, :owner_id
    remove_column :pay_charges, :processor
    remove_column :pay_subscriptions, :owner_type
    remove_column :pay_subscriptions, :owner_id
    remove_column :pay_subscriptions, :processor

    MODELS.each do |klass|
      remove_column klass.table_name, :processor
      remove_column klass.table_name, :processor_id
      remove_column klass.table_name, :pay_data
      remove_column klass.table_name, :trial_ends_at
      remove_column klass.table_name, :card_type
      remove_column klass.table_name, :card_last4
      remove_column klass.table_name, :card_exp_month
      remove_column klass.table_name, :card_exp_year
      remove_column klass.table_name, :trial_ends_at
    end
  end
end
