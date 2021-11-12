# Upgrade Guide

Follow this guide to upgrade older pay versions. These may require database migrations and code changes.

## Pay 2.x to Pay 3.0

This is a major change to add support for multiple payment methods, fixing bugs, and improving the architecture of Pay.

### Database Migrations

Upgrading from Pay 2.x to 3.0 requires moving data for several things:

1. Move `processor` and `processor_id` from billable models to the new Pay::Customer model
2. Associate existing `Pay::Charge` and `Pay::Subscription` records with new `Pay::Customer` records.
3. Sync default card for each `Pay::Customer` to `Pay::PaymentMethod` records (makes API requests)
4. Update `Pay::Charge` payment method details for each record to the new format
5. Convert generic trials from billable model to FakeProcessor subscriptions with trial
6. Drop unneeded columns

Here's an example migration for migrating data. This migration is purely an example for reference. Please modify this migration as needed.
A quick walkthrough of both migrations is available in this video (starting at 6:40): https://www.youtube.com/watch?v=nJLf26sGD3o

```ruby
class CreatePayV3Models < ActiveRecord::Migration[6.0]
  def change
    create_table :pay_customers do |t|
      t.belongs_to :owner, polymorphic: true, index: false
      t.string :processor
      t.string :processor_id
      t.boolean :default
      t.public_send Pay::Adapter.json_column_type, :data
      t.datetime :deleted_at

      t.timestamps
    end
    # Index for `payment_processor` and `pay_customer` associations
    add_index :pay_customers, [:owner_type, :owner_id, :deleted_at], name: :customer_owner_processor_index

    # Index typically used by webhooks
    add_index :pay_customers, [:processor, :processor_id]

    create_table :pay_merchants do |t|
      t.belongs_to :owner, polymorphic: true, index: false
      t.string :processor
      t.string :processor_id
      t.boolean :default
      t.public_send Pay::Adapter.json_column_type, :data

      t.timestamps
    end
    add_index :pay_merchants, [:owner_type, :owner_id, :processor]

    create_table :pay_payment_methods do |t|
      t.belongs_to :customer, foreign_key: {to_table: :pay_customers}, index: false
      t.string :processor_id
      t.boolean :default
      t.string :type
      t.public_send Pay::Adapter.json_column_type, :data

      t.timestamps
    end
    add_index :pay_payment_methods, [:customer_id, :processor_id], unique: true

    create_table :pay_webhooks do |t|
      t.string :processor
      t.string :event_type
      t.public_send Pay::Adapter.json_column_type, :event

      t.timestamps
    end

    rename_column :pay_charges, :pay_subscription_id, :subscription_id

    add_column :pay_charges, :application_fee_amount, :integer
    add_column :pay_charges, :currency, :string
    add_column :pay_charges, :metadata, Pay::Adapter.json_column_type
    add_column :pay_subscriptions, :application_fee_percent, :decimal, precision: 8, scale: 2
    add_column :pay_subscriptions, :metadata, Pay::Adapter.json_column_type

    remove_index :pay_charges, [:processor, :processor_id] if index_exists?(:pay_charges, [:processor, :processor_id])
    remove_index :pay_subscriptions, [:processor, :processor_id] if index_exists?(:pay_subscriptions, [:processor, :processor_id])

    add_reference :pay_charges, :customer, foreign_key: {to_table: :pay_customers}, index: false
    add_reference :pay_subscriptions, :customer, foreign_key: {to_table: :pay_customers}, index: false
    add_index :pay_charges, [:customer_id, :processor_id], unique: true
    add_index :pay_subscriptions, [:customer_id, :processor_id], unique: true
  end
end
```

```ruby
class UpgradeToPayVersion3 < ActiveRecord::Migration[6.0]
  # List of models to migrate from Pay v2 to Pay v3
  MODELS = [User, Team]

  def self.up
    # Migrate models to Pay::Customer
    MODELS.each do |klass|
      klass.where.not(processor: nil).find_each do |record|
        # Migrate to Pay::Customer
        pay_customer = Pay::Customer.where(owner: record, processor: record.processor, processor_id: record.processor_id).first_or_initialize
        pay_customer.update!(
          default: true,
          data: {
            stripe_account: record.try(:stripe_account),
            braintree_account: record.try(:braintree_account),
          }
        )
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

    # Associate Pay::Charges with new Pay::Customer
    Pay::Charge.find_each do |charge|
      # Since customers can switch between payment processors, we have to find or create
      owner = charge.owner_type.constantize.find_by(id: charge.owner_id)
      next unless owner

      customer = Pay::Customer.where(owner: owner, processor: charge.processor).first_or_create!

      # Data column should be a hash. If we find a string instead, replace it
      charge.data = {} if charge.data.is_a?(String)

      case charge.card_type.downcase
      when "paypal"
        charge.update!(customer: customer, payment_method_type: :paypal, brand: "PayPal", email: charge.card_last4)
      else
        charge.update!(customer: customer, payment_method_type: :card, brand: charge.card_type, last4: charge.card_last4, exp_month: charge.card_exp_month, exp_year: charge.card_exp_year)
      end
    end

    # Associate Pay::Subscriptions with new Pay::Customer
    Pay::Subscription.find_each.each do |subscription|
      # Since customers can switch between payment processors, we have to find or create
      owner = subscription.owner_type.constantize.find_by(id: subscription.owner_id)
      next unless owner
      customer = Pay::Customer.where(owner: owner, processor: subscription.processor).first_or_create!

      # Data column should be a hash. If we find a string instead, replace it
      subscription.data = {} if subscription.data.is_a?(String)
      subscription.update!(customer: customer)
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
      if ActiveRecord::Base.connection.column_exists?(klass.table_name, :pay_data)
        remove_column klass.table_name, :pay_data
      end
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
```

After running migrations, run the following to sync the customer default payment methods to the Pay::PaymentMethods table.
```ruby
rake pay:payment_methods:sync_default
```

### Pay::Customer

The `Pay::Billable` module has been removed and is replaced with `pay_customer` method on your models.

```ruby
class User
  pay_customer
  pay_merchant
end
```

This adds associations and a couple methods for interacting with Pay.

Instead of adding fields to your models, Pay now manages everything in a `Pay::Customer` model that's associated with your models. You set the default payment processor

```ruby
# Choose a payment provider
user.set_payment_processor :stripe
#=> Creates a Pay::Customer object with associated Stripe::Customer

user.payment_processor
#=> Returns the default Pay::Customer for this user (or nil)

user.pay_customers
#=> Returns all the pay customers associated with this User
```

### Payment Processor

Instead of calling `@user.charge`, Pay 3 moves the `charge`, `subscribe`, and other methods to the `payment_processor` association. This significantly reduces the methods added to the User model.

You can switch between payment processors at anytime and Pay will mark the most recent one as the default. It will also retain the previous Pay::Customers so they can be reused as needed.

```ruby
user.set_payment_processor :stripe

# Charge Stripe::Customer $10
user.payment_processor.charge(10_00)

user.set_payment_processor :braintree
#=> Creates a Pay::Customer object with default: true and associated Braintree::Customer
#=> Updates Pay::Customer for stripe with default: false

user.payment_processor.subscribe(plan: "whatever")
# Subscribes Braintree::Customer to "whatever" plan
# Creates Pay::Subscription record for the subscription
```

### Generic Trials

Generic trials are now done using the fake payment processor

```ruby
user.set_payment_processor :fake_processor, allow_fake: true
user.payment_processor.subscribe(trial_ends_at: 14.days.from_now, ends_at: 14.days.from_now)
user.payment_processor.on_trial? #=> true
```

### Charges & Subscriptions

`Pay::Charge` and `Pay::Subscription` are associated `Pay::Customer` and no longer directly connected to the `owner`

### Payment Methods

Pay 3 now keeps track of multiple payment methods. Each is associated with a Pay::Customer and one is marked as the default.

We also now support every payment method (previously only Card or PayPal). This means you can store Venmo details, iDeal, FPX, or any other payment method supported by Stripe, Braintree, etc.

To do this, we reformatted the charge and payment method details so they're easier to access:

```ruby
charge.payment_method_type #=> "card"
charge.brand #=> "Visa"
charge.last4 #=> "4242"

charge.payment_method_type #=> "paypal"
charge.email #=> "test@example.org"
```

### Configuration Changes

We've removed several configuration options since Pay 3+ will always use the models from the gem for charges, subscriptions, etc.

Removed options:
* Pay.billable_class
* Pay.billable_table
* Pay.chargeable_class
* Pay.chargeable_table
* Pay.subscription_class
* Pay.subscription_table
