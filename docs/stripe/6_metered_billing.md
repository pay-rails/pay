# Stripe Metered Billing

Metered billing are subscriptions where the price fluctuates monthly. For example, you may spin up servers on DigitalOcean, shut some down, and keep others running. Metered billing allows you to report usage of these servers and charge according to what was used.

```ruby
@user.payment_processor.subscribe(plan: "price_metered_billing_id")
```

This will create a new metered billing subscription. You can then create meter events to bill for usage:

```ruby
@user.payment_processor.create_meter_event(:api_request, payload: { value: 1 })
```

If your price is using the legacy usage records system, you will need to use the below method:

```ruby
pay_subscription.create_usage_record(quantity: 99)
```

If your subscription has multiple SubscriptionItems, you can specify the `subscription_item_id` to be used:

```ruby
pay_subscription.create_usage_record(subscription_item_id: "si_1234", quantity: 99)
```

## Failed Payments

If a metered billing subscription fails, it will fall into a `past_due` state.

After payment attempts fail, Stripe will either leave the subscription alone, cancel it, or mark it as `unpaid` depending on the settings in your Stripe account.
We recommend marking the subscription as `unpaid`.

You can notify your user to update their payment method. Once they do, you can retry the open payment to bring their subscription back into the active state.

## Next

See [Stripe Tax](7_stripe_tax.md)
