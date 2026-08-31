# Pay Gem: Payment Processor Architecture Analysis

## Overview

The Pay gem uses a modular, processor-agnostic architecture allowing multiple payment processors to be plugged in. Each processor implements a common interface while handling processor-specific logic.

---

## 1. Base Class/Pattern All Processors Inherit From

### Core Inheritance Hierarchy

**Models:**
- **`Pay::Customer`** (base in `app/models/pay/customer.rb`)
  - Extended by processor-specific versions: `Pay::Stripe::Customer`, `Pay::PaddleBilling::Customer`, etc.
  
- **`Pay::Charge`** (base in `app/models/pay/charge.rb`)
  - Extended by: `Pay::Stripe::Charge`, `Pay::PaddleBilling::Charge`, etc.
  
- **`Pay::Subscription`** (base in `app/models/pay/subscription.rb`)
  - Extended by: `Pay::Stripe::Subscription`, `Pay::PaddleBilling::Subscription`, etc.
  
- **`Pay::PaymentMethod`** (base in `app/models/pay/payment_method.rb`)
  - Extended by: `Pay::Stripe::PaymentMethod`, `Pay::PaddleBilling::PaymentMethod`, etc.

### Module Files

Each processor has a corresponding module file in `lib/pay/` that handles:
- Configuration and setup
- Credentials management (api_key, signing_secret, etc.)
- Version validation
- Webhook configuration

Example structure:
```
lib/pay/
├── stripe.rb              # Module with setup, config, credentials
├── stripe/
│   └── webhooks/          # Webhook handlers
├── paddle_billing.rb      # Module with setup, config, credentials
├── paddle_billing/
│   └── webhooks/
└── ... (other processors)
```

### Inheritance Pattern Example

```ruby
# Base
module Pay
  class Customer < Pay::ApplicationRecord
    # Defines the interface all processors must implement
  end
end

# Processor-specific
module Pay
  module Stripe
    class Customer < Pay::Customer
      # Implements Stripe-specific logic
      include Pay::Routing  # For stripe_account support
      
      def charge(amount, options = {})
        # Stripe implementation
      end
      
      def subscribe(name:, plan:, **options)
        # Stripe implementation
      end
    end
  end
end
```

---

## 2. Required Methods Each Processor Must Implement

### For Customer Model

The customer is the primary interface for payment operations.

#### Core Methods (Required)

```ruby
# 1. api_record
# Returns the processor's customer object (creates if needed)
def api_record(expand: [])
  # Example (Stripe):
  # if processor_id?
  #   ::Stripe::Customer.retrieve(id: processor_id)
  # else
  #   ::Stripe::Customer.create(attributes).tap { |c| update!(processor_id: c.id) }
  # end
end

# 2. api_record_attributes
# Returns Hash of attributes for creating/updating processor customer
def api_record_attributes
  # Example:
  # { email: email, name: customer_name }
end

# 3. update_api_record
# Syncs customer data to processor
def update_api_record(**attributes)
  # Example:
  # ::Stripe::Customer.update(processor_id, attributes)
end

# 4. charge
# Creates one-time charge
# Returns: Pay::Charge model instance
def charge(amount, options = {})
  # Must handle:
  # - amount (in cents)
  # - options (payment_method, currency, etc.)
  # Must call: charges.create! with processor_id
  # Example (FakeProcessor):
  # charges.create!(
  #   processor_id: NanoId.generate,
  #   amount: amount,
  #   data: { payment_method_type: :card, ... }
  # )
end

# 5. subscribe
# Creates a subscription
# Returns: Pay::Subscription model instance
def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
  # Must handle:
  # - name (subscription name)
  # - plan (plan/price ID)
  # - trial_period_days, quantity, etc. in options
  # Must call: subscriptions.create! with processor_id
  # Example (FakeProcessor):
  # subscriptions.create!(
  #   processor_id: NanoId.generate,
  #   name: name,
  #   processor_plan: plan,
  #   status: :active,
  #   trial_ends_at: trial_period_days.days.from_now
  # )
end

# 6. add_payment_method
# Adds/attaches a payment method to customer
# Returns: Pay::PaymentMethod model instance
def add_payment_method(payment_method_id, default: false)
  # Must handle:
  # - payment_method_id (token from processor)
  # - default (whether to make it default)
  # Must call: payment_methods.create! or update!
end
```

### For Charge Model

```ruby
# 1. self.sync (class method)
# Syncs charge data from processor API to database
# Returns: Pay::Charge instance or updates existing
def self.sync(processor_id, object: nil, stripe_account: nil, **options)
  # Must handle:
  # - Retrieve charge from processor API if object not provided
  # - Create or update Pay::Charge record
  # - Extract relevant attributes into data JSON
  # Example attributes: brand, last4, exp_month, exp_year, etc.
  # Example (Stripe):
  # charge = object || ::Stripe::Charge.retrieve(processor_id)
  # Pay::Stripe::Charge.create!(
  #   customer: pay_customer,
  #   processor_id: charge.id,
  #   amount: charge.amount,
  #   data: extract_attributes(charge)
  # )
end

# 2. api_record
# Returns the processor's charge/transaction object
def api_record
  # Example: ::Stripe::Charge.retrieve(processor_id)
end

# 3. refund!
# Refunds the charge (fully or partially)
def refund!(amount_to_refund = nil, **options)
  # amount_to_refund defaults to full amount if not specified
  # Example: ::Stripe::Refund.create(charge: processor_id, amount: amount)
end
```

### For Subscription Model

```ruby
# 1. self.sync (class method)
# Syncs subscription data from processor API to database
def self.sync(subscription_id, object: nil, name: nil, **options)
  # Must handle:
  # - Retrieve subscription from processor API
  # - Extract status, trial_ends_at, current_period_*, ends_at
  # - Create or update Pay::Subscription record
end

# 2. cancel
# Marks subscription to cancel at period end
def cancel(**options)
  # Example: ::Stripe::Subscription.update(processor_id, cancel_at_period_end: true)
end

# 3. cancel_now!
# Cancels subscription immediately
def cancel_now!(**options)
  # Example: ::Stripe::Subscription.cancel(processor_id)
end

# 4. resume
# Resumes a paused subscription (if supported)
def resume(**options)
end

# 5. swap
# Changes subscription plan
def swap(plan, **options)
end

# 6. update_payment_method
# Updates the payment method for subscription
def update_payment_method(payment_method_id)
end
```

### For PaymentMethod Model

```ruby
# 1. self.sync (class method)
# Syncs payment method data from processor
def self.sync(payment_method_id, object: nil, **options)
  # Extracts: brand, last4, exp_month, exp_year, etc.
  # Creates or updates Pay::PaymentMethod record
end
```

---

## 3. Simple Processor Implementation Example: FakeProcessor

The FakeProcessor is the simplest, most readable implementation. Perfect for understanding the pattern.

### Structure

```
app/models/pay/fake_processor/
├── charge.rb
├── customer.rb
├── payment_method.rb
└── subscription.rb

lib/pay/
└── fake_processor.rb
```

### Implementation Details

#### Customer (`app/models/pay/fake_processor/customer.rb`)

```ruby
module Pay
  module FakeProcessor
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: "Pay::FakeProcessor::Charge"
      has_many :subscriptions, dependent: :destroy, class_name: "Pay::FakeProcessor::Subscription"
      has_many :payment_methods, dependent: :destroy, class_name: "Pay::FakeProcessor::PaymentMethod"
      has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::FakeProcessor::PaymentMethod"

      def api_record
        # Generate processor_id if not exists
        update!(processor_id: NanoId.generate) unless processor_id?
        self
      end

      def update_api_record(**attributes)
        self  # No-op for fake
      end

      def charge(amount, options = {})
        api_record  # Ensure processor_id exists

        attributes = {
          processor_id: NanoId.generate,
          amount: amount,
          data: {
            payment_method_type: :card,
            brand: "Fake",
            last4: 1234,
            exp_month: Date.today.month,
            exp_year: Date.today.year
          }
        }.deep_merge(options.slice(*Pay::Charge.attribute_names.map(&:to_sym)))

        charges.create!(attributes)
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        api_record

        attributes = options.merge(
          processor_id: NanoId.generate,
          name: name,
          processor_plan: plan,
          status: :active,
          quantity: options.fetch(:quantity, 1)
        )

        # Handle trial_period_days option
        if (trial_period_days = attributes.delete(:trial_period_days))
          attributes[:trial_ends_at] = trial_period_days.to_i.days.from_now
        end

        # Only set valid attribute names
        attributes.deep_stringify_keys!.slice!(*subscriptions.attribute_names)

        subscriptions.create!(attributes)
      end

      def sync_subscriptions(**options)
        []  # Fake processor doesn't sync from external API
      end

      def add_payment_method(payment_method_id, default: false)
        api_record

        pay_payment_method = payment_methods.create!(
          processor_id: NanoId.generate,
          default: default,
          payment_method_type: :card,
          data: {
            brand: "Fake",
            last4: 1234,
            exp_month: Date.today.month,
            exp_year: Date.today.year
          }
        )

        if default
          payment_methods.where.not(id: pay_payment_method.id).update_all(default: false)
          reload_default_payment_method
        end

        pay_payment_method
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_fake_processor_customer, Pay::FakeProcessor::Customer
```

#### Charge (`app/models/pay/fake_processor/charge.rb`)

```ruby
module Pay
  module FakeProcessor
    class Charge < Pay::Charge
      def self.sync(processor_id)
        true  # No-op for fake processor
      end

      def api_record
        self
      end

      def refund!(amount_to_refund = nil)
        update(amount_refunded: amount_to_refund || amount)
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_fake_processor_charge, Pay::FakeProcessor::Charge
```

#### Subscription (`app/models/pay/fake_processor/subscription.rb`)

```ruby
module Pay
  module FakeProcessor
    class Subscription < Pay::Subscription
      def api_record
        self
      end

      def cancel(**options)
        update(ends_at: Time.current)
      end

      def cancel_now!(**options)
        cancel
      end

      def pause(**options)
        update(status: :paused, pause_starts_at: Time.current)
      end

      def resume(**options)
        update(status: :active, pause_starts_at: nil)
      end

      def swap(plan, **options)
        update(processor_plan: plan)
      end

      def sync_payment!
        true
      end

      def self.sync(subscription_id, object: nil, **options)
        # No-op for fake processor
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_fake_processor_subscription, Pay::FakeProcessor::Subscription
```

---

## 4. Directory Structure for New Processor

To add a new payment processor (e.g., "MyPayment"):

### Directory Structure

```
lib/pay/
├── my_payment.rb                    # Module with config, setup, credentials
├── my_payment/
│   ├── webhooks/                    # Webhook handlers
│   │   ├── charge_refunded.rb
│   │   ├── charge_succeeded.rb
│   │   ├── subscription_created.rb
│   │   └── subscription_updated.rb
│   └── ... (other webhook events)
│
app/models/pay/my_payment/
├── customer.rb                      # Main entry point, handles customers/charges/subscriptions
├── charge.rb                        # Charge sync and operations
├── subscription.rb                  # Subscription sync and operations
├── payment_method.rb                # Payment method sync
└── merchant.rb                      # (Optional) For marketplace payments

app/controllers/pay/my_payment/
├── webhooks_controller.rb           # Webhook endpoint handler
└── ... (optional additional controllers)
```

### Key Module File: `lib/pay/my_payment.rb`

```ruby
module Pay
  module MyPayment
    class Error < Pay::Error
    end

    module Webhooks
      autoload :ChargeSucceeded, "pay/my_payment/webhooks/charge_succeeded"
      autoload :ChargeRefunded, "pay/my_payment/webhooks/charge_refunded"
      autoload :SubscriptionCreated, "pay/my_payment/webhooks/subscription_created"
      autoload :SubscriptionUpdated, "pay/my_payment/webhooks/subscription_updated"
    end

    extend Env  # Provides credential lookup

    REQUIRED_VERSION = "~> X.Y"  # Specify required gem version

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:my_payment) && defined?(::MyPaymentGem)

      Pay::Engine.version_matches?(required: REQUIRED_VERSION, current: ::MyPaymentGem::VERSION) || 
        (raise "[Pay] my_payment gem must be version #{REQUIRED_VERSION}")
    end

    def self.setup
      ::MyPaymentGem.api_key = api_key
      # Additional setup...
    end

    # Credential access methods (stored in Rails credentials or ENV vars)
    def self.api_key
      find_value_by_name(:my_payment, :api_key)
    end

    def self.signing_secret
      find_value_by_name(:my_payment, :signing_secret)
    end

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        events.subscribe "my_payment.charge.succeeded", Pay::MyPayment::Webhooks::ChargeSucceeded.new
        events.subscribe "my_payment.charge.refunded", Pay::MyPayment::Webhooks::ChargeRefunded.new
        events.subscribe "my_payment.subscription.created", Pay::MyPayment::Webhooks::SubscriptionCreated.new
        events.subscribe "my_payment.subscription.updated", Pay::MyPayment::Webhooks::SubscriptionUpdated.new
      end
    end
  end
end
```

### Key Model File: `app/models/pay/my_payment/customer.rb`

```ruby
module Pay
  module MyPayment
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: "Pay::MyPayment::Charge"
      has_many :subscriptions, dependent: :destroy, class_name: "Pay::MyPayment::Subscription"
      has_many :payment_methods, dependent: :destroy, class_name: "Pay::MyPayment::PaymentMethod"
      has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::MyPayment::PaymentMethod"

      def api_record_attributes
        { email: email, name: customer_name }
      end

      def api_record
        if processor_id?
          ::MyPaymentGem::Customer.retrieve(id: processor_id)
        else
          customer = ::MyPaymentGem::Customer.create(api_record_attributes)
          update!(processor_id: customer.id)
          customer
        end
      rescue ::MyPaymentGem::Error => e
        raise Pay::MyPayment::Error, e
      end

      def update_api_record(**attributes)
        api_record unless processor_id?
        ::MyPaymentGem::Customer.update(processor_id, api_record_attributes.merge(attributes))
      rescue ::MyPaymentGem::Error => e
        raise Pay::MyPayment::Error, e
      end

      def charge(amount, options = {})
        # Implementation
      rescue ::MyPaymentGem::Error => e
        raise Pay::MyPayment::Error, e
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        # Implementation
      rescue ::MyPaymentGem::Error => e
        raise Pay::MyPayment::Error, e
      end

      def add_payment_method(payment_method_id, default: false)
        # Implementation
      rescue ::MyPaymentGem::Error => e
        raise Pay::MyPayment::Error, e
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_my_payment_customer, Pay::MyPayment::Customer
```

---

## 5. How Models and Migrations Work

### Database Schema

The migrations in `db/migrate/` create the core tables used by all processors:

```ruby
# db/migrate/1_create_pay_tables.rb

create_table :pay_customers do |t|
  t.belongs_to :owner, polymorphic: true    # Links to User/Account/etc
  t.string :processor, null: false          # 'stripe', 'paddle_billing', etc
  t.string :processor_id                    # Customer ID in processor
  t.boolean :default
  t.json :data                              # Processor-specific data
  t.string :stripe_account                  # For Stripe Connect
  t.datetime :deleted_at
  t.timestamps
end

create_table :pay_charges do |t|
  t.belongs_to :customer, foreign_key: { to_table: :pay_customers }
  t.belongs_to :subscription, optional: true
  t.string :processor_id, null: false       # Charge ID in processor
  t.integer :amount, null: false            # In cents
  t.string :currency
  t.integer :amount_refunded
  t.json :metadata
  t.json :data                              # payment_method_type, brand, last4, etc
  t.timestamps
end

create_table :pay_subscriptions do |t|
  t.belongs_to :customer, foreign_key: { to_table: :pay_customers }
  t.string :name, null: false               # 'default', 'premium', etc
  t.string :processor_id, null: false
  t.string :processor_plan, null: false     # Plan ID in processor
  t.integer :quantity
  t.string :status                          # 'active', 'paused', 'canceled', etc
  t.datetime :current_period_start
  t.datetime :current_period_end
  t.datetime :trial_ends_at
  t.datetime :ends_at
  t.boolean :metered
  t.string :pause_behavior
  t.json :metadata
  t.json :data
  t.timestamps
end

create_table :pay_payment_methods do |t|
  t.belongs_to :customer, foreign_key: { to_table: :pay_customers }
  t.string :processor_id, null: false
  t.boolean :default
  t.string :type                            # STI: 'Pay::Stripe::PaymentMethod'
  t.json :data                              # brand, last4, exp_month, exp_year, etc
  t.timestamps
end

create_table :pay_webhooks do |t|
  t.string :processor                       # 'stripe', 'paddle_billing', etc
  t.string :event_type                      # 'charge.refunded', etc
  t.json :event                             # Raw webhook data
  t.timestamps
end
```

### Data Storage Pattern

The `data` JSON columns store processor-specific attributes:

```ruby
# In Pay::Charge
store_accessor :data, :payment_method_type  # 'card', 'paypal', 'sepa', etc
store_accessor :data, :brand                # 'Visa', 'Mastercard', 'PayPal'
store_accessor :data, :last4
store_accessor :data, :exp_month
store_accessor :data, :exp_year
store_accessor :data, :email                # For PayPal, etc
store_accessor :data, :bank

# Access:
charge.payment_method_type  # => 'card'
charge.brand                # => 'Visa'
charge.last4                # => '4242'
```

### Model Relationships

```ruby
# Typical workflow
owner = User.first
customer = Pay::Customer.create(
  owner: owner, 
  processor: 'stripe'
  # processor_id set by api_record call
)

# Add payment method
payment_method = customer.add_payment_method('pm_123')

# Create subscription
subscription = customer.subscribe(
  name: 'premium',
  plan: 'price_123',
  payment_method: payment_method
)

# Create one-time charge
charge = customer.charge(5000)  # $50.00 in cents

# Query relationships
owner.pay_customers          # All customers for this owner
customer.charges             # All charges
customer.subscriptions       # All subscriptions
customer.payment_methods     # All payment methods
subscription.charges         # Charges for this subscription
```

### STI (Single Table Inheritance) for Models

Processor-specific models inherit from base models with STI:

```ruby
# All stored in pay_payment_methods table with 'type' column
class PaymentMethod < ApplicationRecord
  # type => 'Pay::Stripe::PaymentMethod'
  # type => 'Pay::PaddleBilling::PaymentMethod'
end

# Query by processor
Pay::Stripe::PaymentMethod.all      # Only Stripe payment methods
Pay::PaddleBilling::PaymentMethod.all # Only Paddle Billing methods
```

---

## 6. Webhook Architecture

### Webhook Flow

```
1. External Payment Processor sends webhook POST
   ↓
2. WebhooksController receives and validates signature
   ↓
3. Pay::Webhooks.instrument("processor.event_type", event_data)
   ↓
4. Registered webhook handler processes event
   ↓
5. Handler syncs data to database (updates Pay models)
```

### Example Webhook Handler

```ruby
# lib/pay/stripe/webhooks/charge_succeeded.rb
module Pay
  module Stripe
    module Webhooks
      class ChargeSucceeded
        def call(event)
          charge = event.data.object
          
          # Sync the charge from Stripe API to database
          Pay::Stripe::Charge.sync(
            charge.id, 
            stripe_account: event.try(:account)
          )
        end
      end
    end
  end
end
```

### Webhook Handler Registration

```ruby
# In lib/pay/stripe.rb
def self.configure_webhooks
  Pay::Webhooks.configure do |events|
    events.subscribe "stripe.charge.succeeded", Pay::Stripe::Webhooks::ChargeSucceeded.new
    events.subscribe "stripe.charge.refunded", Pay::Stripe::Webhooks::ChargeRefunded.new
    events.subscribe "stripe.subscription.created", Pay::Stripe::Webhooks::SubscriptionCreated.new
  end
end
```

### Webhook Delegation

```ruby
# In lib/pay/webhooks/delegator.rb
# Receives: processor name + event type
# Looks up subscribed handler and calls it
delegator.instrument("stripe.charge.succeeded", event_data)
# Calls all handlers subscribed to "stripe.charge.succeeded"
```

---

## 7. Key Design Patterns

### 1. Include Concerns/Modules for Shared Functionality

```ruby
module Pay
  module Stripe
    class Customer < Pay::Customer
      include Pay::Routing  # Provides stripe_options helper
    end
  end
end
```

### 2. Error Wrapping

```ruby
# Each processor catches its own errors and wraps in Pay::ProcessorName::Error
begin
  ::Stripe::Customer.create(...)
rescue ::Stripe::StripeError => e
  raise Pay::Stripe::Error, e
end
```

### 3. With Lock Pattern for Concurrency

```ruby
# Prevents race conditions when updating records
pay_customer.with_lock do
  pay_customer.update!(processor_id: customer.id)
end
```

### 4. .sync() Class Method Pattern

```ruby
# Idempotent sync from processor to database
def self.sync(processor_id, object: nil, **options)
  # Fetch from API if not provided
  object ||= ::Processor::Resource.retrieve(processor_id)
  
  # Find or create Pay model
  pay_model = find_by(processor_id: processor_id)
  
  if pay_model
    pay_model.with_lock { pay_model.update!(attributes) }
  else
    create!(attributes)
  end
end
```

### 5. Storing Full API Response

```ruby
# Store complete API response in data column for audit trail
attrs = {
  object: payment_intent.to_hash,  # Full response
  amount: payment_intent.amount,
  # ... other extracted fields
}
```

---

## 8. Configuration & Credentials

### Loading Credentials

```ruby
# In lib/pay/env.rb - extended by processor modules
def self.find_value_by_name(processor_name, attribute_name)
  # 1. Check environment variable first
  #    ENV["#{PROCESSOR_NAME_UPCASED}_#{ATTRIBUTE_UPCASED}"]
  
  # 2. Check Rails credentials (env-scoped and unscoped)
  #    config.#{processor_name}.#{attribute_name}
  
  # 3. Return nil if not found
end

# Usage in processor
def self.api_key
  find_value_by_name(:stripe, :private_key)
end
```

### Configuration Example

```yaml
# config/credentials.yml.enc
stripe:
  public_key: pk_test_...
  private_key: sk_test_...
  signing_secret: whsec_test_...
  context: ctx_... # Optional for Stripe Connect

paddle_billing:
  client_token: client-...
  api_key: api_key...
  signing_secret: pdl_...
```

---

## Summary Table

| Aspect | Details |
|--------|---------|
| **Base Classes** | `Pay::Customer`, `Pay::Charge`, `Pay::Subscription`, `Pay::PaymentMethod` |
| **Inheritance** | Processor inherits from base (e.g., `Pay::Stripe::Customer < Pay::Customer`) |
| **Main Methods** | `charge()`, `subscribe()`, `add_payment_method()`, `cancel()`, `refund!()` |
| **Sync Pattern** | `.sync(processor_id)` class method pulls data from processor API to database |
| **Storage** | JSON `data` column stores processor-specific attributes, `processor_id` links to external system |
| **Webhooks** | Event handlers transform processor webhooks into Pay model updates |
| **Error Handling** | Each processor wraps API errors in `Pay::ProcessorName::Error` |
| **Testing** | FakeProcessor provides no-op implementation for testing |
