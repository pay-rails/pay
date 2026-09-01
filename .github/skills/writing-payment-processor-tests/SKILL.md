---
name: writing-payment-processor-tests
description: 'Set up and write tests for payment processors. Use when: adding tests for new payment processors, writing charge/subscription/customer tests, setting up VCR cassettes for HTTP mocking, testing webhook handlers, debugging payment processor behavior.'
argument-hint: 'Describe the test scope (e.g., "Stripe charge tests", "new BTCPay processor tests", "webhook event tests")'
---

# Writing Payment Processor Tests

## When to Use

- Adding test coverage for a **new payment processor**
- Writing **charge, subscription, or customer tests** for existing processors
- Setting up **VCR cassettes** to record/replay API interactions
- Testing **webhook event handlers**
- Debugging payment processor behavior without making real API calls
- Adding **error handling tests** for processor failures

## Test Architecture Overview

The pay gem uses a **parallel test structure** where each payment processor (Stripe, Braintree, Paddle, Lemon Squeezy, BTCPay, Fake Processor) follows the same test pattern:

```
test/pay/<processor>/
├── charge_test.rb              # Creating, refunding, syncing charges
├── customer_test.rb            # Customer creation, payment methods
├── payment_method_test.rb      # Payment method operations
├── subscription_test.rb        # Subscription management
├── error_test.rb               # Error handling & exceptions
└── webhooks/                   # Webhook event handlers
    └── *.rb                    # One test file per webhook event
```

**Test Infrastructure:**
- **VCR**: Records HTTP interactions → stored in `test/vcr_cassettes/*.yml`
- **Mocha**: Mocking framework for stubbing objects
- **Fixtures**: JSON webhook payloads in `test/fixtures/files/<processor>/`
- **Helpers**: Fake object generators in `test/support/<processor>.rb`

## Step-by-Step Procedure

### 1. Set Up Test Files for a New Processor

Create the directory structure:

```bash
mkdir -p test/pay/<processor>/webhooks
```

Then create the test files using the templates below.

**File: `test/pay/<processor>/charge_test.rb`**
```ruby
require "test_helper"

class Pay::<ProcessorName>::ChargeTest < ActiveSupport::TestCase
  setup do
    @pay_customer = users(:one).payment_customer
  end

  test "sync returns Pay::Charge" do
    # Use VCR cassette to replay recorded API interaction
    charge = Pay::<ProcessorName>::Charge.sync("<processor_id>")
    assert charge.is_a?(Pay::Charge)
  end

  test "charged? returns true for successful charges" do
    # Use fake API record or mock
    charge = @pay_customer.charges.create!(
      processor_id: "charge_123",
      amount_in_cents: 1000
    )
    # Call api_record or implement charged? method
    assert charge.charged?
  end

  test "refund! refunds a charge" do
    charge = @pay_customer.charges.create!(
      processor_id: "charge_123", 
      amount_in_cents: 1000
    )
    charge.refund!
    # Assert refund was processed
  end
end
```

**File: `test/pay/<processor>/subscription_test.rb`**
```ruby
require "test_helper"

class Pay::<ProcessorName>::SubscriptionTest < ActiveSupport::TestCase
  setup do
    @pay_customer = users(:one).payment_customer
  end

  test "can create a subscription" do
    travel_to_cassette do
      subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")
      assert subscription.active?
    end
  end

  test "sync updates subscription status" do
    subscription = Pay::<ProcessorName>::Subscription.sync("<processor_id>")
    assert subscription.is_a?(Pay::Subscription)
  end
end
```

**File: `test/pay/<processor>/customer_test.rb`**
```ruby
require "test_helper"

class Pay::<ProcessorName>::CustomerTest < ActiveSupport::TestCase
  setup do
    @pay_customer = users(:one).payment_customer
  end

  test "can create a customer" do
    # Processor should handle customer creation
    assert @pay_customer.processor_customer
  end

  test "can update payment method" do
    payment_method = @pay_customer.payment_methods.create!(processor_id: "pm_123")
    payment_method.make_default!
    assert payment_method.default?
  end
end
```

**File: `test/pay/<processor>/payment_method_test.rb`**
```ruby
require "test_helper"

class Pay::<ProcessorName>::PaymentMethodTest < ActiveSupport::TestCase
  include Pay::PaymentMethodTests  # Shared behavior tests
  
  setup do
    @pay_customer = users(:one).payment_customer
  end

  # Add processor-specific tests here
end
```

**File: `test/pay/<processor>/error_test.rb`**
```ruby
require "test_helper"

class Pay::<ProcessorName>::ErrorTest < ActiveSupport::TestCase
  setup do
    @pay_customer = users(:one).payment_customer
  end

  test "handles invalid amount errors" do
    exception = assert_raises(Pay::<ProcessorName>::Error) do
      @pay_customer.charge(0)  # Invalid amount
    end
    assert_match /amount.*invalid/i, exception.message
  end

  test "handles authentication errors" do
    exception = assert_raises(Pay::<ProcessorName>::Error) do
      # Trigger authentication failure
    end
    assert_match /authentication|unauthorized/i, exception.message
  end
end
```

### 2. Create Test Fixtures (Webhook Payloads)

Store JSON webhook payloads in `test/fixtures/files/<processor>/`:

**File: `test/fixtures/files/<processor>/charge_succeeded.json`**
```json
{
  "id": "evt_123",
  "type": "charge.succeeded",
  "data": {
    "object": {
      "id": "ch_123",
      "amount": 1000,
      "currency": "usd",
      "status": "succeeded"
    }
  }
}
```

Load fixtures in tests:
```ruby
test "handles charge succeeded webhook" do
  event_data = json_fixture("stripe/charge.succeeded.json")
  webhook = Pay::Stripe::Webhooks::ChargeSucceeded.new
  webhook.call(event_data)
  # Assert charge was updated
end
```

### 3. Set Up VCR Cassettes for API Recording

VCR automatically records HTTP interactions in cassettes named after test methods.

**VCR Configuration** (already set up in `test/support/vcr.rb`):
- Records to: `test/vcr_cassettes/test_<method_name>.yml`
- Filters sensitive data (API keys, IDs, etc.)
- Replays cassettes instead of making real API calls

**Using VCR in Tests:**

```ruby
test "stripe_can_create_a_subscription" do
  travel_to_cassette do  # Travel time to match cassette recording
    @pay_customer.update_payment_method(payment_method)
    subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")
    assert subscription.active?
  end
end
```

When test runs:
1. If cassette exists: `test_stripe_can_create_a_subscription.yml` — replays HTTP interactions
2. If cassette missing: Records real API call (requires API credentials)

**To Record New Cassettes:**

```bash
# Set processor API credentials
export PROCESSOR_API_KEY="your_test_key"
export PROCESSOR_SIGNING_SECRET="your_test_secret"

# Run test (VCR will record cassette)
ruby -Itest test/pay/stripe/subscription_test.rb -n test_stripe_can_create_a_subscription

# Cassette is saved and sensitive data is filtered
cat test/vcr_cassettes/test_stripe_can_create_a_subscription.yml
```

### 4. Use Test Helpers and Fakes

**Stripe Example** (from `test/support/stripe.rb`):

```ruby
test "creates a charge with payment method" do
  fake_payment_method = fake_stripe_payment_method()
  fake_charge = fake_stripe_charge()
  
  charge = Pay::Stripe::Charge.sync("ch_123", object: fake_charge)
  assert charge.charged?
end
```

**Create processor-specific helpers in `test/support/<processor>.rb`:**

```ruby
# test/support/btcpay.rb
def fake_btcpay_invoice
  {
    "id" => "inv_123",
    "amount" => "0.001",
    "currency" => "BTC",
    "status" => "settled",
    "exceptionStatus" => nil
  }
end

def fake_btcpay_charge(overrides = {})
  Pay::Btcpay::Charge.new(overrides)
end
```

### 5. Testing Webhook Handlers

**File: `test/pay/<processor>/webhooks/charge_succeeded_test.rb`**

```ruby
require "test_helper"

class Pay::<ProcessorName>::Webhooks::ChargeSucceededTest < ActiveSupport::TestCase
  setup do
    @pay_charge = pay_charges(:one)
  end

  test "updates charge status from webhook event" do
    event = json_fixture("<processor>/charge_succeeded.json")
    Pay::<ProcessorName>::Webhooks::ChargeSucceeded.new.call(event)
    
    @pay_charge.reload
    assert @pay_charge.charged?
  end

  test "creates charge if not found" do
    event = json_fixture("<processor>/charge_succeeded.json")
    Pay::<ProcessorName>::Webhooks::ChargeSucceeded.new.call(event)
    
    charge = Pay::Charge.find_by(processor_id: event.dig("data", "object", "id"))
    assert charge.charged?
  end
end
```

### 6. Run Tests with Different Scopes

```bash
# Run all tests
rake test

# Run tests for a specific processor
ruby -Itest test/pay/stripe/charge_test.rb

# Run a specific test
ruby -Itest test/pay/stripe/charge_test.rb -n test_sync_returns_Pay_Charge

# Run tests with verbose output
ruby -Itest test/pay/stripe/charge_test.rb -v

# Run all webhook tests
ruby -Itest test/pay/stripe/webhooks/*_test.rb
```

### 7. Common Assertions & Patterns

**Pattern 1: Verify charge is synced**
```ruby
charge = Pay::<ProcessorName>::Charge.sync(processor_id)
assert_equal "settled", charge.api_record["status"]
assert charge.charged?
```

**Pattern 2: Test refund flow**
```ruby
charge = @pay_customer.charges.create!(processor_id: "ch_123", amount_in_cents: 1000)
refund = charge.refund!(500)  # Refund half
assert_equal 500, charge.amount_refunded_in_cents
```

**Pattern 3: Test subscription renewal**
```ruby
travel_to_cassette do
  subscription = @pay_customer.subscribe(name: "default", plan: "small-monthly")
  travel 1.month
  Pay::<ProcessorName>::Subscription.sync(subscription.processor_id)
  # Assert renewal event was processed
end
```

**Pattern 4: Test error handling**
```ruby
assert_raises(Pay::<ProcessorName>::Error) do
  @pay_customer.charge(0)
end
```

## Shared Test Infrastructure

### Test Database & Models

- **Database**: SQLite (`test/dummy/pay_test.db`)
- **Models**:
  - `User` (with Stripe billing)
  - `Account` (with Braintree billing)
  - `Team` (multi-processor testing)

### Test Fixtures

JSON payloads: [test/fixtures/files/](../test/fixtures/files/)

Load in tests:
```ruby
json_fixture("<processor>/<event>.json")
```

### Test Helpers

Location: [test/support/](../test/support/)

Key files:
- `test_helper.rb` — Main configuration
- `vcr.rb` — HTTP recording setup
- `<processor>.rb` — Fake object generators
- `payment_method_tests.rb` — Shared behavior mixin

## Reference: Existing Processor Tests

Use these as templates when creating tests for new processors:

- **Stripe** (most comprehensive): [test/pay/stripe/](../test/pay/stripe/)
- **Braintree**: [test/pay/braintree/](../test/pay/braintree/)
- **Paddle Billing**: [test/pay/paddle_billing/](../test/pay/paddle_billing/)
- **Fake Processor** (minimal, no API): [test/pay/fake_processor/](../test/pay/fake_processor/)

## Quick Start: Add a Test for BTCPay Charge

1. **Ensure test file exists**: [test/pay/btcpay/charge_test.rb](../test/pay/btcpay/charge_test.rb)

2. **Add test method**:
   ```ruby
   test "can sync a charge" do
     charge = Pay::Btcpay::Charge.sync("invoice_123")
     assert charge.is_a?(Pay::Charge)
     assert charge.charged?
   end
   ```

3. **Run the test**:
   ```bash
   ruby -Itest test/pay/btcpay/charge_test.rb -n test_can_sync_a_charge
   ```

4. **If VCR cassette needed**, record it:
   ```bash
   export BTCPAY_ENDPOINT="https://your-btcpay.com"
   export BTCPAY_API_KEY="your_key"
   ruby -Itest test/pay/btcpay/charge_test.rb -n test_can_sync_a_charge
   ```

## Troubleshooting

**VCR cassette not found?**
- Check cassette path matches test method name
- Run with real API credentials to record new cassette

**Stubbing not working?**
- Use `Object.stubs(:method)` for Mocha mocking
- Verify mock is set up before the method call

**Time-dependent tests failing?**
- Use `travel_to_cassette` to sync time with VCR recording
- Or use `travel` to move time for subscription tests

**Fixture parsing errors?**
- Verify JSON fixture syntax: `json_fixture("<processor>/<event>.json")`
- Check fixture file exists in `test/fixtures/files/`

## Next Steps

- **Add processor**: Create [test/pay/<new_processor>/](../test/pay/) structure
- **Record cassettes**: Set API credentials and run tests to record interactions
- **Add webhooks**: Create webhook handler tests in [webhooks/](../test/pay/stripe/webhooks/) directory
- **Run full suite**: `rake test` to verify all tests pass
