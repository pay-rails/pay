ℹ️ For upgrade instructions, read the [UPGRADE guide](./UPGRADE.md)

### Unreleased

### 7.3.0

* Stripe v12
* Accept Stripe Connect live and test webhooks in production #1001
* Only sync Stripe Checkout Session charge if it exists

### 7.2.1

* Use empty string to resume / unpause Stripe subscriptions. #992

### 7.2.0

* Add devcontainer for easier development #988
* Stripe 11.x #980
* Update Paddle billing payment method sync #946
* Improve compatibility for fake processor charge with other payment processors by ignoring any non-attribute params. #965

### 7.1.1

* Update `trial_ends_at` when Paddle Billing & Classic subscriptions change to `active` or `past_due` [#936](https://github.com/pay-rails/pay/pull/936)

### 7.1.0

* Add `pay_amount_to_currency` view helper

### 7.0.0

* [Breaking] Rails secrets are no longer supported. Please use Rails credentials or environment variables.
* [Breaking] Stripe now syncs the `default_payment_method` association to Pay::Subscriptions

    ```bash
    rails g migration AddPaymentMethodToPaySubscriptions payment_method_id
    ```

* [Breaking] Paddle Classic is now `paddle_classic` and Paddle Billing is `paddle_billing`.

    To migrate, existing Paddle customers should be updated to `paddle_classic`
    ```ruby
    Pay::Customer.where(processor: :paddle).update_all(processor: :paddle_classic)
    ```

    Rename webhooks for `paddle.*` to `paddle_classic.*`

* [Breaking] `stripe_account` has been moved from the `data:json` column to a dedicated column

    To migrate, create a migration to add the stripe_account column.
    ```ruby
    add_column :pay_customers, :stripe_account, :string
    add_column :pay_subscriptions, :stripe_account, :string
    add_column :pay_payment_methods, :stripe_account, :string
    add_column :pay_charges, :stripe_account, :string
    ```

    Then copy the data over to the column:

    ```ruby
    Pay::Customer.find_each{ |c| c.update(stripe_account: c.data&.dig("stripe_account")) }
    Pay::Subscription.find_each{ |c| c.update(stripe_account: c.data&.dig("stripe_account")) }
    Pay::PaymentMethod.find_each{ |c| c.update(stripe_account: c.data&.dig("stripe_account")) }
    Pay::Charge.find_each{ |c| c.update(stripe_account: c.data&.dig("stripe_account")) }
    ```

* [Breaking] Subscriptions with `status: :canceled` and `ends_at: future` are now considered canceled. Previously, these were considered active to accomodate canceling a Braintree subscription during trial (and allowing the user to continue using until the end of the trial).
* [Breaking] Subscriptions with `status: :past_due` will be canceled immediately when `cancel` is called.
* Updated Stripe Payment confirmation page to use PaymentElement instead of CardElement

### 6.8.1

* [Stripe] Skip sync if object is not attached to a customer. Fixes #842

### 6.8.0

* Update to Stripe `2023-08-16` API version
* [Stripe] Add `pay_customer.create_payment_intent` for creating payment intents without immediate confirmation
* [Stripe] Add `pay_customer.terminal_charge` for creating Stripe Terminal payments

### 6.7.2

* Allow configurable Stripe API version
* Only include success_url and cancel_url for checkout when not embedded mode

### 6.7.1

* Fix payments#show redirect_to not falling back to root_path properly

### 6.7.0

* Add `currency` and `invoice_credit_balance` to Stripe Pay::Customer #825 - @nachiket87
* Safely handle Rails 7.2's removal of secrets. #834 @heliocola

### 6.6.1

* Fix Paddle PayPal payment method details not recording

### 6.6.0

* Add `Pay::Stripe.to_client_reference_id(User.first)` method to generate client_reference_id for use with Stripe's CheckoutSession, Pricing Tables, etc #823
  Unfortunately with the `client_reference_id` requirements, we cannot use Signed GlobalIDs and have to implement our own IDs and validation. If Stripe relaxes their requirements in the future, we could replace this implementation with SGIDs.
* Skip Stripe `customer.deleted` webhook processing if customer is not in the database. #818
* Refactor `on_grace_period?` to be implemented separately by each payment processor
* Add default value of `nil` to the token param of `Pay::Paddle::Billable#add_payment_method`
* Fix `Pay::Paddle::Billable#add_payment_method`. Pass `pay_customer: pay_customer` as keyword arg / value to `sync` call inside `Pay::Paddle::Billable#add_payment_method` method body. #821
* Remove Rails 6.0 from CI now that it is EOL

### 6.5.0

* Add new configuration option named `send_emails` which can be used to disable the sending of all current and future emails.
  This option can be set to a boolean value or a proc/lambda that returns a boolean value. - @cjilbert504

### 6.4.0

* Introduce `:pay` load hook - @excid3
  Rails no longer allows autoloading during the initialization process. The on_load hook allows you to run code after autoloading, so we can register webhook listeners once autoloading is available.

  To use this, wrap your webhook subscribe calls in the `on_load(:pay)` hook:

  ```ruby
    ActiveSupport.on_load(:pay) do
      Pay::Webhooks.delegator.subscribe "stripe.charge.succeded", ChargeSucceeded
    end
  ```

### 6.3.4

* Import Stimulus.js from dist folder on unpkg

### 6.3.3

* Fix `swap_and_invoice`
* Support passing options through `swap` on Stripe

### 6.3.2

* [SECURITY] Fix XSS vulnerability in back parameter on Stripe payment page
  Previously, an attacker could inject Javascript or redirect the user to any URL by changing the `back` parameter in the URL.
  The `back` parameter is now sanitized and restricted to relative paths.
* Remove unused attributes for `plan` and `quantity` in `app/models/pay/customer.rb`.
* Add explicit requires for `active_support` and `action_mailer` in `lib/pay.rb`. This should provide better errors for anyone not requiring all of Rails.

### 6.3.1

* Fix `retry_past_due_subscriptions` to now call `pay_open_invoices`

### 6.3.0

* Add `payment_failed` email to notify customers of failed payments and update their billing information
  This can be disabled with `Pay.emails.payment_failed = true` if you already use a dunning email service
* `subscription` now sorts by `created_at` to find the latest subscription. This adds compatibility for UUID primary keys on pay tables.
* Add `unpaid` scope to Pay::Subscription
* Add `pay_open_invoices` to Pay::Stripe::Subscription
  If you have a subscription with open invoices (like an unpaid metered billing subscription), you can use this method to pay the open invoices and allow the user to resume the subscription

### 6.2.4

* Set `created_at` on Braintree charges to match transaction created_at
* Sync Braintree payment method during subscription sync since we already have to look it up
* Handle missing Braintree subscription when syncing charge
* Fix `Pay::Charge.payment_processor` scopes to join the customers table

### 6.2.3

* Fix Braintree PaymentMethod sync reference to gateway

### 6.2.2

* Fix `pause_active?` for stripe incorrectly returning `true`
* Refactor Braintree cancel / cancel_now to use sync

### 6.2.1

* Use `paid_through_date` for `ends_at` with canceled subscriptions

### 6.2.0

* Add `Pay::Braintree::Subscription.sync`
* Add `Pay::Braintree::Charge.sync`
* Switch Braintree webhooks to use `sync`
* Automatically save first charge when subscribing with Braintree
* Add `email` for PayPal charges and `username` for Venmo charges on Braintree

### 6.1.2

* Fix `refunds` missing on checkout session completed event.

### 6.1.1

* Cast `Pay.support_email` to `Mail::Address` instead of string. This allows us to easily parse out the address, name, etc for use in Receipts and other places.
* Update Stripe `checkout_session.completed` webhook to sync `latest_charge` for compatibility with Stripe API `2022-11-15` changes

### 6.1.0

* Swapping Braintree subscriptions previously had a bug where if a user had an existing plan and was attempting to switch to a new plan, we would cancel their current plan before subscribing them to the new plan.
  If subscribing to the new plan failed however, the user would then no longer have any plan at all. This has now been resolved by attempting to subscribe to the new plan first, which if fails will raise an error and
  preserve the users current plan.
* Switch `business_name` to `application_name` to receipt & mailers
  The business name is included on receipts & refunds, but emails should show the `application_name` instead in case a business has multiple applications / products
* Use `instance_exec` for `mail_arguments` and `mail_to` so lambda/proc has access to all mailer features
* Add `application_name` to email subjects
* Add links to root_url in emails

### 6.0.3

* Validate PaymentIntent on `swap` and `retry_failed_payment`

### 6.0.2

* Retrieve PaymentIntent via API to ensure it always matches the Pay Stripe API verison

### 6.0.1

* Handle ActiveRecord::RecordNotUnique error during sync and retry
* Add retries to Stripe PaymentMethod.sync
* Fix deprecation warning in tests #735

### 6.0.0

* [Breaking] Require Stripe 8.x
* [Breaking] Update Stripe API to 2022-11-15
* [Breaking] `paddle_paused_from` is now `pause_starts_at:datetime` column
* [Breaking] `active` scope no longer includes paused subscriptions
* [Breaking] Stripe paused subscriptions have changed:
  `pause_behavior=void` subscriptions are now considered `active?` until the end of the current period. This is intended for not providing services for a certain period of time.
  `pause_behavior=mark_uncollectible` is considered active. This is intended for offering services for free.
  `pause_behavior=keep_as_draft` is considered active. This is intended for offering serivces for free but collecting payments later.
* [Breaking] Stripe subscriptions now `always_invoice` when swapping plans. Previously, swap would use `proration_behavior: "create_prorations"`. This caused some confusion when users upgraded plans and weren't charged until the next period. The default will now automatically invoice immediately.
* Adds `pause_behavior:string` column
* Adds `pause_resumes_at:datetime` column
* Adds `metered:boolean` column for easier querying / indexing
* Adds `active_or_paused` scope to retrieve active or paused subscriptions
* Remove `off_session: true` default for Stripe `subscribe`. - @excid3
  Removing this allows Stripe to attach the PaymentMethod to the Customer once confirmed. You can still pass this option in when subscribing if needed. New subscriptions typically are initiated by users, which shouldn't provide this parameter as true.
* Add `Pay::Stripe::PaymentMethod.sync_payment_intent` to sync PaymentMethod from PaymentIntent objects
* Add `Pay::Stripe::PaymentMethod.sync_setup_intent` to sync PaymentMethod from SetupIntent objects
* Add `Pay::Subscription#retry_failed_payment` for retrying `past_due` subscriptions with failed payments
* Fix `swap` from always setting status to `active`. Failed swaps with Stripe will be set to `past_due`.

### 5.0.4

* Prepend Pay webhook listeners so they run before user-defined webhook listeners - @excid3 @cjilbert504
  This is important because a user might define a webhook listener that expects a subscription to be deleted and if the Pay webhook hasn't run yet, the subscription would not be canceled when the user-defined webhook runs.
* Fix Webhook delegator unsubscribe - @excid3 @cjilbert504

* Fix non-deterministic subscription - @feliperaul @excid3

### 5.0.3

* Old Pay::Subscription records may have `nil` or `[]` for subscription_items. In those cases, we will set the quantity on the Stripe Subscription directly - @excid3

### 5.0.2

* Add `metered_subscription_item` to Pay::Subscriptions to easily retrieve the metered subscription item for Stripe subscriptions - @excid3
* Add `not_fake_processor` scope to Pay::Customer - @excid3

### 5.0.1

* Fix typo in Stripe API version - @excid3

### 5.0.0

* Upgrade to Stripe API `2022-08-01` and `stripe` rubygem v7 - @excid3

### 4.2.1

* Ensure Customer is created before creating a setup intent - @excid3 @cjilbert504

### 4.2.0

* ℹ️  Add `"paused"` into `.active` scope and `#active?` on `Pay::Subscription`.
    Stripe marks paused subscriptions with `status: :active` and  `pause_behavior` not null.
    Paddle marks paused subscriptions with `status: :paused`.
    This change allows Pay to treat them both the same. - @cjilbert504 @excid3
* Add `active_without_paused` scope on `Pay::Subsctiption`. This filters out paused subscriptions from the `active` scope. - @cjilbert504 @GALTdea
* Add `status: :paused` to update call in `Pay::Paddle::Subscription#pause`. - @cjilbert504 @excid3
* Change `#paused?` in `Pay::Paddle::Subscription` to check `pay_subscription.status == "paused"` instead of `#paddle_paused_from`. - @cjilbert504 @excid3
    If webhooks have not been utilized, you should run query for any `Pay::Subscriptions` where `status: :active` and `paddle_paused_from` is not null and update to `status: "paused"`.

### 4.1.1

* Expand Stripe discounts and taxes when loading a subscription - @excid3

### 4.1.0

* Store Stripe refunds on the Charge - @excid3
* Include line for each refund in the receipt - @excid3

### 4.0.4

* Fix recording first charge for a subscription - @excid3

### 4.0.3

* Fix tax amounts and skip $0 tax lines in Stripe receipts - @excid3

### 4.0.2

* Support `client_reference_id` on Stripe Checkout Sessions - @excid3 @cjilbert504
  This is helpful when using the Stripe Pricing Table or any Checkout Session. Requires a Signed GlobalID as the value to prevent tampering.

```ruby
::Stripe::Checkout::Session.create(
  mode: "payment",
  client_reference_id: current_user.to_sgid,
  ...
)
```

* Stripe `checkout.session.completed` now syncs payment intents - @excid3

### 4.0.1

* Update `refund!` method in `stripe/charge.rb` to handle multiple refunds on the same charge. - @cjilbert504 @kyleschmolze
* Add configuration options for mailer - @excid3 @le-doude @cjilbert504

```ruby
Pay.setup do |config|
  # Change parent mailer for Pay::UserMailer
  config.parent_mailer = "MyCustomMailer"

  # Change the mailer for Pay
  config.mailer = "MyCustomMailer"
```

### 4.0.0

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
    * `stripe ~> 6.0`
    * `braintree ~> 4.7`
    * `paddle_pay ~> 0.2`
    * `receipts ~> 2.0`
* Add `credit_note!` to Stripe charges - @excid3
* `refund!` now issues a Stripe::CreditNote if an invoice is present - @excid3
  > Refunds of charges associated with an Invoice don’t reduce your overall tax liability and don’t show up in Stripe Tax reporting. https://stripe.com/docs/tax/faq#how-do-refunds-work
  > In most cases, you should use credit notes instead of refunds. Credit notes reduce your overall tax liability and show up in Stripe Tax reporting. https://stripe.com/docs/tax/faq#how-do-you-handle-credit-notes
* Stripe.max_network_retries is now set to 2 by default. - @excid3
  This adds idempotency keys automatically to each request so that they can be safely retried.
* Stripe Subscriptons can now be paused and resumed - @excid3
* Separate authorize and capture is now supported on Stripe - @excid3
  ```ruby
  pay_charge = pay_customer.authorize(75_00)
  pay_charge.capture
  pay_charge.capture(amount_to_capture: 50_00) # or with an amount
  ```
* Store `stripe_receipt_url` on Pay::Charge - @mguidetti
* Replace `update_email!` with `update_customer!` - @excid3
* Add options for `cancel_now!` to support `invoice_now` and `prorate` flags for Stripe - @excid3
* Adds `add_payment_processor` to add a payment processor without making it the default - @excid3
* Setting `pay_name` in Stripe Subscription metadata will be used as the `name` on the `Pay::Subscription` - @excid3
* `pay_customer` now supports a `stripe_attributes:` option to add attributes to Stripe::Customers - @excid3
* `pay_customer` now supports a `braintree_attributes:` option to add attributes to Braintree::Customers - @excid3
* `pay_customer` now supports a `default_payment_processor` option to automatically create a Pay::Customer record - @excid3
* Added `enabled_processors` to Pay config. This lets you choose exactly which processors will be enabled. - @cjilbert504
* Add `sync!` method to Pay::Subscription instances - @excid3
* Ignore Stripe charges that don't have a customer ID - @excid3

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
