# Testing Pay

Pay comes with a fake payment processor to make testing easy. It can also be used in production to give free access to friends, testers, etc.

### Using the Fake Processor

To protect from abuse, the `allow_fake` option must be set to `true` in order to use the Fake Processor.

```ruby
@user.set_pay_payment_processor :fake_processor, allow_fake: true
```

You can then make charges and subscriptions like normal. These will be generated with random unique IDs just like a real payment processor.

```ruby
pay_charge = @user.pay_payment_processor.charge(19_00)
pay_subscription = @user.pay_payment_processor.subscribe(plan: "fake")
```

### Test Examples

You'll want to test the various situations like subscriptions on trial, active, canceled on grace period, canceled permanently, etc.

Fake processor charges and subscriptions will automatically assign these fields to the database for easy testing of different situations:

```ruby
# Canceled subscription
@user.pay_payment_processor.subscribe(plan: "fake", ends_at: 1.week.ago)

# On Trial
@user.pay_payment_processor.subscribe(plan: "fake", trial_ends_at: 1.week.from_now)

# Expired Trial
@user.pay_payment_processor.subscribe(plan: "fake", trial_ends_at: 1.week.ago)
```
