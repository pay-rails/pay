# **Upgrade Guide**

Follow this guide to upgrade older Pay versions. These may require database migrations and code changes.

### ** Pay 7.0 to Pay 8.0**

```bash
rails pay:install:migrations
rails db:migrate
```

The `PaymentMethod#type` column has been renamed to `payment_method_type`. If you're displaying payment method details, you'll need to update your views to use the new column name.

## **Pay 6.0 to Pay 7.0**

Pay 7 introduces some changes for Stripe and requires a few additional columns.

```bash
rails g migration UpgradeToPay7
```

Then add the following migrations.
```ruby
add_column :pay_subscriptions, :payment_method_id, :string
add_column :pay_customers, :stripe_account, :string
add_column :pay_subscriptions, :stripe_account, :string
add_column :pay_payment_methods, :stripe_account, :string
add_column :pay_charges, :stripe_account, :string
```

If you are using Stripe, you can transfer the stripe_account from the json column to the new stripe_account column:

```ruby
Pay::Customer.find_each { |c| c.update(stripe_account: c.data&.dig("stripe_account")) }
Pay::Subscription.find_each { |c| c.update(stripe_account: c.data&.dig("stripe_account")) }
Pay::PaymentMethod.find_each { |c| c.update(stripe_account: c.data&.dig("stripe_account")) }
Pay::Charge.find_each { |c| c.update(stripe_account: c.data&.dig("stripe_account")) }
```

In addition, this version adds support for Paddle's new Billing APIs and renames the existing Paddle implementation to Paddle Classic.

If you were using Paddle before, you'll need to update existing Paddle customers to `paddle_classic`.

```ruby
Pay::Customer.where(processor: :paddle).update_all(processor: :paddle_classic)
```

You'll also need to update the Webhook endpoint from `/pay/webhooks/paddle` to `/pay/webhooks/paddle_classic`
And rename custom webhooks from `paddle.*` to `paddle_classic.*`

The secrets/environment variables for Paddle have also been renamed to from `PADDLE_*` to `PADDLE_CLASSIC_*`

The `paddle_pay` gem requirement has been replaced with `paddle`, which contains APIs for both Paddle Billing and Classic.

## **Pay 5.0 to 6.0**
This version adds support for accessing the start and end of the current billing period of a subscription. This currently only works with Stripe subscriptions.

Fields changed:
- Adds `current_period_start` and `current_period_end` to `Pay::Subscription`
- Adds `metered` to `Pay::Subscription` for metered billing
- Adds `pause_behavior`, `pause_starts_at`, and `pause_resumes_at` to `Pay::Subscription`

Backfills metered and paused columns from data json column

To upgrade you must add and run the following database migration.

```ruby
class UpgradeToPayVersion6 < ActiveRecord::Migration[6.0]
  def change
    add_column :pay_subscriptions, :current_period_start, :datetime
    add_column :pay_subscriptions, :current_period_end, :datetime

    add_column :pay_subscriptions, :metered, :boolean
    add_column :pay_subscriptions, :pause_behavior, :string
    add_column :pay_subscriptions, :pause_starts_at, :datetime
    add_column :pay_subscriptions, :pause_resumes_at, :datetime

    add_index :pay_subscriptions, :metered
    add_index :pay_subscriptions, :pause_starts_at

    Pay::Subscription.find_each do |pay_subscription|
      pay_subscription.update(
        metered: pay_subscription.data&.dig("metered"),
        pause_behavior: pay_subscription.data&.dig("pause_behavior"),
        pause_starts_at: pay_subscription.data&.dig("paddle_paused_from"),
        pause_resumes_at: pay_subscription.data&.dig("pause_resumes_at")
      )
    end
  end
end
```

Stripe subscriptions created before this upgrade will gain the `current_period_start` and `current_period_end` attributes the next time they are synced. You can manually sync a Stripe subscription by running `Pay::Stripe::Subscription.sync("STRIPE_SUBSCRIPTION_ID")`


## **Pay 3.0 to 4.0**

This is a major change to add Stripe tax support, Stripe metered billing, new configuration options for payment processors and emails, syncing additional customer attributes to Stripe and Braintree, and improving the architecture of Pay.

### **Jump to a topic**
- [Method Additions and Changes](#method-additions-and-changes)
- [Custom Email Sending Configuration](#custom-email-sending-configuration)
- [Customer Attributes](#customer-attributes)
- [Stripe Tax Support](#stripe-tax-support)
- [Stripe Metered Billing Support](#stripe-metered-billing-support)
- [Enabling Payment Processors](#enabling-payment-processors)
- [Supported Dependency Notifications](#supported-dependency-notifications)

### **Method Additions and Changes**

In an effort to keep a consistant naming convention, the email parameters of `subscription` and `charge` have been updated to have `pay_` prepended to them (`pay_subscription` and `pay_charge` respectively). If you are directly using any of the built in emails or created custom Pay views, you will want to be sure to update your parameter names to the updated names.

You'll need to replace all references to:
```ruby
params[:charge] with params[:pay_charge]
params[:subscription] with params[:pay_subscription]
```

The `send_emails` configuration variable has been removed from Pay and replaced by the new configuration system which is discussed below. `Pay.send_emails` is primarily used internally, but if you have been using it in your application code you will need to update those areas to use the new method calls from the email configuration settings. For example, to check if the receipt email should be sent you can now call `Pay.send_email?(:receipt)`. If your email configuration option uses a lambda, you can pass any additional arguments to `send_email?` like so `Pay.send_email?(:receipt, pay_charge)` for use in the lambda.

The `update_email!` method has been replaced with `update_customer!`. When dealing with a `Stripe::Billable` or `Braintree::Billable` object, a hash of additional attributes can be passed in that will be merged into the default atrributes.

The `Stripe::Subscription#cancel_now!` method now accepts a hash of options such as `cancel_now!(prorate: true, invoice_now: true)` which will be handled automatically by Stripe.

The `set_payment_processor` method has a `make_default` optional argument that defaults to `true`.

Setting the `metadata["pay_name"]` option on a `Stripe::Subscription` object will now set the subscription name if present. Otherwise the `Pay.default_product_name` will be used to set the name.

### **Custom Email Sending Configuration**

Previously, Pay would send out the following emails based on the value of the `send_emails` configuration variable, which was set to true by default:

- A payment action is required
- A charge succeeded
- A charge was refunded
- A yearly subscription is about to renew

This behavior could be overridden by creating an initializer at `config/initializers/pay.rb`, calling the `setup` class method and setting the `send_emails` config option to `false`.
This would disable all of the previously mentioned emails from being sent.
With this new release, it is possible to configure each email separately as to whether it should be sent or not by setting each email option to either a boolean value or a lambda that returns a boolean inside the setup block of an initializer at `config/initializers/pay.rb`. As an example:
```ruby
# config/initializers/pay.rb

Pay.setup do |config|
  config.emails.payment_action_required = true
  config.emails.receipt = true
  config.emails.refund = true
  config.emails.subscription_renewing = ->(pay_subscription, price) { (price&.type == "recurring") && (price.recurring&.interval == "year") }
end
```
The above example shows the exact defaults that come pre-configured from Pay. The `config.emails.subscription_renewing` example is specific to Stripe but illustrates how a lambda can be used as a way to evaluate more complex conditions to determine whether an email should be sent. All of these settings can be overridden using the initializer mentioned previously and setting your own values for each email.

### **Customer Attributes**

The `pay_customer` macro now accepts options for `stripe_attributes` and `braintree_attributes`. These options can accept a method name or a lambda that returns a hash of `pay_customer` attributes. For example:
```ruby
class User < ApplicationRecord
  pay_customer stripe_attributes: :custom_stripe_customer_attributes_method # You would define this method in the model that has this declaration.
  def custom_stripe_customer_attributes_method(pay_customer)
    {
      address: {
        city: pay_customer.owner.city,
        country: pay_customer.owner.country
      },
      metadata: {
        pay_customer_id: pay_customer.id,
        user_id: id # or pay_customer.owner_id
      }
    }
  end

  # Or using a lambda:
  pay_customer stripe_attributes: ->(pay_customer) { metadata: { { user_id: pay_customer.owner_id } } }
end
```

Being able to send additional customer attributes to Stripe such as the customers address gives you the ability to leverage Stripe's tax support!

### **Stripe Tax Support**

Using `pay_customer stripe_attributes: :method_name`, you can add an `address` key to `Stripe::Customer` objects which will be used for calculating taxes. `total_tax_amounts` are recorded to `Pay::Charge` records. This includes details for each tax applied to the charge, for example if there are multiple jurisdictions involved. Additionally, when subscribing a customer to a plan the `automatic_tax:` parameter can be enabled as shown here:

```ruby
@user.payment_processor.subscribe(plan: "growth", automatic_tax: { enabled: true })
```

### **Stripe Metered Billing Support**

Stripe metered billing support removes `quantity` when creating a new subscription (metered billing prices do not allow quantity). Adds `create_usage_record` to `Pay::Subscription` for reporting usage on metered billing plans. The `create_usage_record` method takes a hash of options, see the example below:
```ruby
create_usage_record(subscription_item_id: "si_1234", quantity: 100, action: :set)
```
To learn more about creating usage records, see [reporting usage](https://stripe.com/docs/products-prices/pricing-models#reporting-usage)

### **Enabling Payment Processors**

Previously, all payment processors were enabled by default. With this new release, Pay now allows you to enable any of the payment processors independently. The use case here is that perhaps you already have an implementation in place in your application for one of the processors that we allow integration with and do not want the Pay implementation to conflict. In such a case you can create or add to an initializer at `config/initializers/pay.rb` the following line, including in the array only the process that you wish Pay to setup in your application:
```ruby
# config/initializers/pay.rb

Pay.setup do |config|
  # All processors are enabled by default. If a processor is already implemented in your application, you can omit it from this list and the processor will not be set up through the Pay gem.
  config.enabled_processors = [:stripe, :braintree, :paddle]
end
```

### **Supported Dependency Notifications**

As Pay is working to setup the payment processors that you have enabled it performs a version check on each to ensure that you are using a compatible version.

Pay depends on the following payment processor gem versions:
- `stripe ~> 6.0`
- `braintree ~> 4.7`
- `paddle_pay ~> 0.2`
- `receipts ~> 2.0`

If you are using a non-compatible version Pay will raise an error message to notify you of the incompatibility so that it can be addressed before proceeding.

---

## **Pay 2.x to Pay 3.0**

This is a major change to add support for multiple payment methods, fixing bugs, and improving the architecture of Pay.

### **Jump to a topic**
- [Database Migrations](#database-migrations)
- [Pay::Customer](#paycustomer)
- [Payment Processor](#payment-processor)
- [Generic Trials](#generic-trials)
- [Charges & Subscriptions](#charges--subscriptions)
- [Payment Methods](#payment-methods)
- [Configuration Changes](#configuration-changes)

### **Database Migrations**

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
    add_column :pay_charges, :card_type, :string
    add_column :pay_charges, :card_last4, :string
    add_column :pay_charges, :card_exp_month, :string
    add_column :pay_charges, :card_exp_year, :string
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

### **Pay::Customer**

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

### **Payment Processor**

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

### **Generic Trials**

Generic trials are now done using the fake payment processor

```ruby
user.set_payment_processor :fake_processor, allow_fake: true
user.payment_processor.subscribe(trial_ends_at: 14.days.from_now, ends_at: 14.days.from_now)
user.payment_processor.on_trial? #=> true
```

### **Charges & Subscriptions**

`Pay::Charge` and `Pay::Subscription` are associated `Pay::Customer` and no longer directly connected to the `owner`

### **Payment Methods**

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

### **Configuration Changes**

We've removed several configuration options since Pay 3+ will always use the models from the gem for charges, subscriptions, etc.

Removed options:
* Pay.billable_class
* Pay.billable_table
* Pay.chargeable_class
* Pay.chargeable_table
* Pay.subscription_class
* Pay.subscription_table
