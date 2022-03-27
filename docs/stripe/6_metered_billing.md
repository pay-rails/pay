# Stripe Metered Billing

Metered billing are subscriptions where the price fluctuates monthly. For example, you may spin up servers on DigitalOcean, shut some down, and keep others running. Metered billing allows you to report usage of these servers and charge according to what was used.

```ruby
@user.payment_processor.subscribe(plan: "price_metered_billing_id")
```

This will create a new metered billing subscription.

To report usage, you will need to create usage records for the `SubscriptionItem`. You can do that using the Pay helper:

```ruby
pay_subscription.create_usage_record(quantity: 99)
```

If your subscription has multiple SubscriptionItems, you can specify the `subscription_item_id` to be used:

```ruby
pay_subscription.create_usage_record(subscription_item_id: "si_1234", quantity: 99)
```

## Next

See [Stripe Tax](7_stripe_tax.md)
