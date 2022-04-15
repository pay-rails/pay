### Unreleased

* [Breaking] Replaced `subscription` and `charge` email params to `pay_subscription` and `pay_charge` respectively. - @cjilbert504
* [Breaking] Replaced `send_emails` with `emails` config. This allows you to customize which emails can be sent independently. - @cjilbert504
```ruby
Pay.setup do |config|
  # Set value to boolean
  config.emails.receipt = true
  # Or set value to a lambda that returns a boolean
  config.emails.subscription_renewing = ->(pay_subscription, price) {
    (price&.type == "recurring") && (price.recurring&.interval == "year")
  }
end
```

* Numericality validation on `Pay::Subscription` has been updated from being `greater_than_or_equal_to: 1` to `greater_than_or_equal_to: 0`. This is because metered billing subscriptions do not have a quantity.

* Stripe Tax support

  Using `pay_customer stripe_attributes: :method_name`, you can add an Address to `Stripe::Customer` objects which will be used for calculating taxes.
  We now record `total_tax_amounts` to `Pay::Charge` records. This includes details for each tax applied to the charge.

  ```ruby
  @user.payment_processor.subscribe(plan: "growth", automatic_tax: { enabled: true })
  ```

* Stripe Metered Billing support
  Removes `quantity` when creating a new subscription (metered billing prices do not allow quantity)
  Adds `create_usage_record` to `Pay::Subscription` for reporting usage on metered billing plans
  Adds `metered_items?` helper to `Pay::Subscription` to easily check if a subscription has any metered billing items
  Adds `Pay::Subscription.with_metered_items` method to query for subscriptions with metered billing items

* Raise error when dependencies are not supported versions. This makes sure you're using supported versions of libraries with Pay.
  Currently supported versions:
    * `stripe ~> 5`
    * `braintree ~> 4`
    * `paddle_pay ~> 0.2`
    * `receipts ~> 2`

* Stripe Subscriptons can now be paused and resumed - @excid3
* Replace `update_email!` with `update_customer!` - @excid3
* Add options for `cancel_now!` to support `invoice_now` and `prorate` flags for Stripe - @excid3
* Adds `add_payment_processor` to add a payment processor without making it the default - @excid3
* Setting `pay_name` in Stripe Subscription metadata will be used as the `name` on the `Pay::Subscription` - @excid3
* `pay_customer` now supports a `stripe_attributes:` option to add attributes to Stripe::Customers - @excid3
* `pay_customer` now supports a `braintree_attributes:` option to add attributes to Braintree::Customers - @excid3
* `pay_customer` now supports a `default_payment_processor` option to automatically create a Pay::Customer record - @excid3
* Added `enabled_processors` to Pay config. This lets you choose exactly which processors will be enabled. - @cjilbert504
* Add `sync!` method to Pay::Subscription instances - @excid3

### 3.0.24

* Make payment method and charges consistent for Fake procsesor - @excid3

### 3.0.23

* Merge Stripe Checkout `session_id` param into `success_url` automatically - @excid3

### 3.0.22

* Update to `@hotwired/stimulus` for payments view - @excid3
* Update test/dummy app to Pay 3 - @excid3

### 3.0.21

* Add `update_customer` methods for SyncCustomer job - @excid3

### 3.0.20

* Safely handle receipts for users without `extra_billing_info` - @excid3

### 3.0.19

* Correctly handle cancelling a paused Paddle subscription - @excid3

### 3.0.18

* Add `generic_trial?` to `Pay::Subscription` for checking if fake processor trial - @excid3
* Charge succeeded should send email even when receipts gem isn't available - @excid3
* Update mailers to use `Pay::Customer#customer_name` - @excid3
* Use `pay_customer` instead of `billable` in mailers - @excid3
* Remove payment methods when cancelling Paddle subscription - @excid3

### 3.0.17

* Convert `paddle_paused_from` to Time - @excid3

### 3.0.16

* Remove hardcoded currency in emails - @excid3

### 3.0.15

* Accept options for `Pay::Currency.format` - @excid3

### 3.0.14

* Add `amount_with_currency` to `Pay::Payment` - @excid3

### 3.0.13

* Add `Pay::Currency` for formatting amounts with currency - @excid3
* Add `amount_with_currency` and `amount_refunded_with_currency` to `Pay::Charge` - @excid3
* Safer pay processor lookup when processor is blank - @excid3
* Store `stripe_account` when syncing Stripe payment methods - @excid3

### 3.0.12

* Add `CHECKOUT_SESSION_ID` to checkout URLs by default and document how to add them - @excid3
* Fix invoice bill_to to use `customer.owner` instead of `owner` - @excid3

### 3.0.11

* Fix Stripe charge.refunded webhook - @excid3

### 3.0.10

* Fix Pay::Subscription charges association - @excid3
* Remove Pay::Charge default sort - @excid3

### 3.0.9

* Fix translation key - @excid3

### 3.0.8

* Better invoice line items format - @excid3

### 3.0.7

* Namespace locales under `pay` - @excid3
* I18n receipt and invoice dates - @excid3
* Add `business_logo` config - @excid3
* Add `refunded?` `partial_refund?` and `full_refund?` methods to `Pay::Charge` - @excid3

### 3.0.6

* Fix payment method sync on customer updated - @excid3

### 3.0.5

* Fix Stripe customer.updated webhook - @excid3

### 3.0.4

* Add retries for payment method sync in case of rate limiting - @excid3
* Add `on_generic_trial?` to Pay::Customer for easier checking - @excid3

### 3.0.3

Yanked

### 3.0.2

* Add payment methods to Pay::Charge `charged_to` helper - @excid3
* Improve `swap` error message - @excid3

### 3.0.1

* Add `rake pay:payment_methods:sync_default` task for easily upgrading to Pay 3 - @excid3

### 3.0.0

See the [UPGRADE](UPGRADE.md) guide for steps on upgrading from Pay 2.x.

* **Requires Rails 6+**
* Migrates `processor` and `processor_id` from models to `Pay::Customer` model
* Replaces include Pay::Billable with pay_customer method
* Replaces include Pay::Merchant with pay_merchant method
* Changes Pay::Charge to associate with Pay::Customer instead of `owner{polymorphic}`
* Changes Pay::Subscription to associate with `Pay::Customer` instead of `owner{polymorphic}`
* Migrates card fields from models to `Pay::PaymentMethod` model
* Queues webhooks in `Pay::Webhook` for processing with ActiveJob to handle large volumes of webhooks
* Subscriptions are automatically canceled when a Pay::Subscription deleted - @stevepolitodesign
* Active subscriptions are canceled when a Pay::Customer's owner is deleted - @stevepolitodesign
* Add `invoice` to Pay::Charge

### 2.7.2

* Don't validate SetupIntent for trialing subscriptions - @archonic
* Validate uniqueness of charges and subscriptions - @excid3
* Better handle out of order webhooks and race conditions - @excid3

### 2.7.1

* Refactor Stripe webhooks to always retrieve latest records - @excid3
* Associate charges with subscriptions if possible - @excid3

### 2.7.0

* Add `Pay::Merchant` and Stripe Connect functionality - @excid3
* Save `currency` on Pay::Charge records - @excid3

### 2.6.11

* Add `subscription` method to payment processor classes for direct access to the processor subscription object.
  The owner is not guaranteed to be on the same payment processor, which can cause problems. - @excid3

### 2.6.10

* Improve the Stripe Checkout URLs so your Rails app doesn't need a `root_url` #309 - @excid3
* Fix `currency` with Stripe Checkout #308 - @excid3

### 2.6.9

* Update Stripe & Braintree default card automatically when the customer is accessed (ie. on charge, subscribe, etc) #300 - @excid3

### 2.6.8

* Add passthrough fallback for paddle payment succeeded webhook #302 - @nm

### 2.6.7

* Add Stripe `payment_intent.succeeded` webhook listener

### 2.6.6

* Improve error wrappers to delegate message to original cause

### 2.6.5

* [NEW] Raise error if payment processor name is nil
* [FIX] Pay::Error now uses the correct message in to_s
* Create braintree customer on update_card if needed

# 2.6.4

* [NEW] Fake payment processor for testing and giving users free access to your application
* [FIX] Delegate trial_ends_at for subscriptions - @archonic

# 2.6.3

* [FIX] Default to empty hash when default_url_options is nil so proper error is raised
* [FIX] Fix inquiry when processor is nil

### 2.6.2

* [FIX] Correctly handle updating payment method in Stripe

### 2.6.1

* [NEW] Add Stripe Customer Billing Portal - @excid3
* Include `customer` on Stripe Checkout sessions - @excid3

### 2.6.0

* [NEW] Stripe Checkout support - @excid3

### 2.5.0

* [BREAKING] Webhooks that can't be verified respond with 400 instead of 200 - @excid3
* [BREAKING] Remove StripeEvent dependency - excid3
* [BREAKING] Remove old configuration for mailer subjects in favor of locales - @excid3
* [NEW] Add `Pay::Webhook.delegator` for subscribing to webhooks - @excid3

### 2.4.4

* [Fix] Fixed missing require for version file - @excid3

### 2.4.3

* Add Stripe app info and join the Stripe Partner program for better support for Pay! - @excid3

### 2.4.2

* [FIX] Update migration to check for symobl keys on ActiveRecord adapter with Rails 6.1 - @excid3

### 2.4.1

* [FIX] Move Paddle logic into paddle methods - @excid3

### 2.4.0

* [BREAKING] Use locales for email subjects and remove configuration - @excid3

### 2.3.1

* [FIX] Subject for payment action required emails referenced an invalid config - @excid3

### 2.3.0

* Add `data` json column to Charge and Subscription models - @excid3

To add the new migrations to your app, run:

```
rails pay:install:migrations
```

* Add Paddle initial support - @nm
* `Pay.model_parent_class` defaults to `ApplicationRecord` - @excid3
* Test suite now runs against sqlite, mysql, and postgresql - @excid3
* [FIX] Lookup billable on invoice.payment_action_required events - @excid3

### 2.2.2

* Bugfixes

### 2.2.1

* [NEW] Allow passing `?back=/path/to/item` for customizing the back link for SCA payments page

### 2.2.0

Stripe API 2020-08-27 changes:

* Use `proration_behavior` instead of `prorate` for Stripe subscription changes
* Switch to `::Stripe::Subscription.create` instead of `customer.subscriptions` as Stripe no longer includes this by default for performance
* Set Stripe API version for easier gem management

### 2.1.3

* Add support for `quantity` option on `subscribe` for subscription quantities
* Added `Pay::BraintreeAuthorizationError` to catch Braintree actions
  with malformed data or unauthorized API access.

### 2.1.2

* [FIX] Remove old billable migration

### 2.1.1

* [FIX] The `charge` method now raises `Pay::BraintreeError` when a
  charge fails. This makes it work consistently with the Stripe
  implementation which raises an error on charge failure.

### 2.1.0

* [BREAKING] Subscription & Charge associations to `owner` are now polymorphic.

  Requires adding `owner_type:string` to both Pay::Charge and Pay::Subscription models and setting the value for all existing records to your model name.

```ruby
class AddOwnerTypeToPay < ActiveRecord::Migration[6.0]
  def change
    add_column :pay_charges, :owner_type, :string
    add_column :pay_subscriptions, :owner_type, :string

    # Backfill owner_type column to match your Billable model
    Pay::Charge.update_all owner_type: "User"
    Pay::Subscription.update_all owner_type: "User"
  end
end
```

  `Pay.billable_class` is now deprecated and will be removed in a future version. You should also update your existing Pay migrations to reference the `:users` table rather than `Pay.billable_class` and any other code you may have that references this method.

### 2.0.3

* [FIX] Stripe subscription cancel shouldn't change status
* [FIX] Stripe test payment methods should now work (ie. `pm_card_visa`)

### 2.0.2

* [FIX] Styling tweaks for payment intent page

### 2.0.1

* [FIX] Stripe Refund and Charge references weren't matching the right
  class

### 2.0.0

* [NEW] Stripe SCA support
* [BREAKING] Requires using PaymentMethods instead of Source and Tokens
* [BREAKING] Drops Ruby 2.4 support
* [BREAKING] `automount_webhook_routes` config option has been renamed to `automount_routes`
* [BREAKING]`webhooks_path` config option has been renamed to `routes_path`
* Added `status` column to payments to keep in sync with Stripe. We're
  also adding statuses to Braintree subscriptions to keep them in sync as best we can.
* Added `payments#show` route to handle SCA payments that require action
* Added webhook handler for payments that require action
* Added `trial_period_days` when creating a subscription that works the
  same on Stripe and Braintree

### 1.0.3

* Set default from email to `Pay.support_email`

### 1.0.2

* Add `on_trial_or_subscribed?` convenience method

### 1.0.1

* Removed Rails HTML Sanitizer dependency since it wasn't being used

### 1.0.0

* Add `stripe?`, `braintree?`, and `paypal?` to Pay::Charge
* Add webhook mounting and path options

### 1.0.0.beta4 - 2019-03-26

* Makes `stripe?`, `braintree?`, and `paypal?` helper methods always
  available on Billable.

### 1.0.0.beta3 - 2019-03-12

* Update migration to reference Billable instead of Users

### 1.0.0.beta2 - 2019-03-11

* Check ENV first when looking up keys to allow for overrides
