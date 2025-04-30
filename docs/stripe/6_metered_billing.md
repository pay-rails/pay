# Stripe Metered Billing

Metered billing are subscriptions where the price fluctuates monthly. For example, you may spin up servers on DigitalOcean, shut some down, and keep others running. Metered billing allows you to report usage of these servers and charge according to what was used.

```ruby
@user.payment_processor.subscribe(plan: "price_metered_billing_id")
```

This will create a new metered billing subscription. You can then create meter events to bill for usage:

```ruby
@user.payment_processor.create_meter_event(:api_request, payload: { value: 1 })
```

## Failed Payments

If a metered billing subscription fails, it will fall into a `past_due` state.

After payment attempts fail, Stripe will either leave the subscription alone, cancel it, or mark it as `unpaid` depending on the settings in your Stripe account.
We recommend marking the subscription as `unpaid`.

You can notify your user to update their payment method. Once they do, you can retry the open payment to bring their subscription back into the active state.

## Migrating from Usage Records to Billing Meters

Follow the Stripe migration guide here: https://docs.stripe.com/billing/subscriptions/usage-based-legacy/migration-guide

While transitioning, you'll need to continue reporting Usage Records and Meters at the same time. You'll need to use Pay v9 until this is completed since Stripe v15 removes Usage Records entirely.

Stripe will raise an error when creating a Usage Record for a Billing Meter subscription, so you can rescue from `Stripe::InvalidRequestError` to ignore those.

Here's an example Rake task to migrate from old prices to new prices.

```ruby
task migrate_to_meters: :environment do
  old_price = "price_1234"
  new_price = "price_5678"

  ::Stripe::Subscription.list({price: old_price, expand: ["data.schedule"]}).auto_paging_each do |stripe_subscription|
    puts "Migrating #{stripe_subscription.id}..."

    # Create a subscription schedule if not present
    subscription_schedule = stripe_subscription.schedule
    subscription_schedule ||= ::Stripe::SubscriptionSchedule.create({from_subscription: stripe_subscription.id})

    # Keep all the existing phases
    phases = subscription_schedule.phases.map do |phase|
      {
        start_date: phase.start_date,
        end_date: phase.end_date,
        trial_end: phase.trial_end,
        items: phase.items.map { {price: it.price} }
      }
    end

    # Subscription has already been migrated
    if phases.any? { it[:items].include?({price: new_price}) }
      puts "Already migrated #{stripe_subscription.id}."
      next
    end

    # Add the new phase
    phases += [{items: [{price: new_price}]}]

    # Save to Stripe
    ::Stripe::SubscriptionSchedule.update(subscription_schedule.id, {phases: phases})

    puts "Migrated #{stripe_subscription.id}"
  end
end
```

## Next

See [Stripe Tax](7_stripe_tax.md)
