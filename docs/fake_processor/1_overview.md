# Fake Payment Processor

The fake payment processor is useful for:

* Testing
* Free subscriptions & charges for users like your team, friends, etc

## Usage

Simply assign `processor: :fake_processor, processor_id: rand(1_000_000), pay_fake_processor_allowed: true` to your user.

```ruby
user = User.create!(
  email: "gob@bluth.com",
  processor: :fake_processor,
  processor_id: rand(1_000_000),
  pay_fake_processor_allowed: true
)

user.charge(25_00)
user.subscribe("default")
```

## Security

You don't want malicious users using the fake processor to give themselves free access to your products.

Pay provides a virtual attribute and validation to ensure the fake processor is only assigned when explicitly allowed.

```ruby
# Inside Pay::Billable
attribute :pay_fake_processor_allowed, :boolean, default: false

validate :pay_fake_processor_is_allowed

def pay_fake_processor_is_allowed
  return unless processor == "fake_processor"
  errors.add(:processor, "must be a valid payment processor") unless pay_fake_processor_allowed?
end
```

`pay_fake_processor_allowed` must be set to `true` before saving. This attribute should *not* included in your permitted_params.

The validation checks if this attribute is enabled and raises a validation error if not. This prevents malicious uses from submitting `user[processor]=fake_processor` in a form.

## Trials Without Payment Method

To create a trial without a card, we can use the Fake Processor to create a subscription with matching trial and end times.

```ruby
time = 14.days.from_now
@user.set_payment_processor :fake_processor, allow_fake: true
@user.pay_payment_processor.subscribe(trial_ends_at: time, ends_at: time)
```

This will create a fake subscription in our database that we can use. Once expired, the customer will need to subscribe using a real payment processor.

```ruby
@user.pay_payment_processor.on_generic_trial?
#=> true
```
