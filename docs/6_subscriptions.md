# Subscriptions

Subscriptions are handled differently by each payment processor. Pay does its best to treat them the same.

Pay stores subscriptions in the `Pay::Subscription` model. Each subscription has a `name` that you can use to handle multiple subscriptions per customer.

## Creating a Subscription

To subscribe a user, you can call the `subscribe` method.

```ruby
@user.payment_processor.subscribe(name: "default", plan: "monthly")
```

You can pass additional options to go directly to the payment processor's API. For example, the `quantity` option to subscribe to a plan with for per-seat pricing.

```ruby
@user.payment_processor.subscribe(name: "default", plan: "monthly", quantity: 3)
```

Subscribe takes several arguments and options:

* `name` - A name for the subscription that's used internally. This allows a customer to have multiple subscriptions. Defaults to `"default"`
* `plan` - The Plan or Price ID to subscribe to. Defaults to `"default"`
* `quantity` - The quantity of the subscription. Defaults to `1`
* `trial_period_days` - Number of days for the subscription's trial.
* Other options may be passed and will be sent directly to the payment processor's API.

##### Paddle Subscriptions

Paddle does not allow you to create a subscription through the API.

Instead, Pay uses webhooks to create the the subscription in the database. The Paddle [passthrough parameter](https://developer.paddle.com/guides/how-tos/checkout/pass-parameters) is required during checkout to associate the subscription with the correct `Pay::Customer`.

In your Javascript, include `passthrough` in Checkout using the `Pay::Paddle.passthrough` helper.

```javascript
Paddle.Checkout.open({
  product: 12345,
  passthrough: "<%= Pay::Paddle.passthrough(owner: current_user) %>"
});
```

Or with Paddle Button Checkout:

```html
<a href="#!" class="paddle_button" data-product="12345" data-email="<%= current_user.email %>" data-passthrough="<%= Pay::Paddle.passthrough(owner: current_user) %>"
```

###### Paddle Passthrough Helper

Pay provides a helper method for generating the `passthrough` JSON object to associate the purchase with the correct Rails model.

```ruby
Pay::Paddle.passthrough(owner: current_user, foo: :bar)
#=> { owner_sgid: "xxxxxxxx", foo: "bar" }

# To generate manually without the helper
#=> { owner_sgid: current_user.to_sgid.to_s, foo: "bar" }.to_json
```

> Pay uses a signed GlobalID to ensure that the subscription cannot be tampered with.

When processing Paddle webhooks, Pay parses the `passthrough` JSON string and verifies the `owner_sgid` hash in order to find the correct `Pay::Customer` record.

The passthrough parameter `owner_sgid` is only required for creating a subscription.

## Retrieving a Subscription from the Database

```ruby
@user.payment_processor.subscription(name: "default")
```

## Subscription Trials

There are two types of trials for subscriptions: with or without a payment method upfront.

Stripe is the only payment processor that allows subscriptions without a payment method. Braintree and Paddle require a payment method on file to create a subscription.

##### Trials Without Payment Method

To create a trial without a card, we can use the Fake Processor to create a subscription with matching trial and end times.

```ruby
time = 14.days.from_now
@user.set_payment_processor :fake_processor, allow_fake: true
@user.payment_processor.subscribe(trial_ends_at: time, ends_at: time)
```

This will create a fake subscription in our database that we can use. Once expired, the customer will need to subscribe using a real payment processor.

```ruby
@user.payment_processor.on_generic_trial?
#=> true
```

##### Trials with Payment Method required

Braintree and Paddle require payment methods before creating a subscription.

```ruby
@user.set_payment_processor :braintree
@user.payment_processor.payment_method_token = params[:payment_method_token]
@user.payment_processor.subscribe()
```

## Checking Customer Subscribed Status

```ruby
@user.payment_processor.subscribed?
```

You can also check for a specific subscription or plan:

```ruby
@user.payment_processor.subscribed?(name: "default", processor_plan: "monthly")
```

## Checking Customer Trial Status

You can check if the user is on a trial by simply asking:

```ruby
@user.payment_processor.on_trial?
#=> true or false
```

You can also check if the user is on a trial for a specific subscritpion name or plan.

```ruby
@user.payment_processor.on_trial?(name: 'default', plan: 'plan')
#=> true or false
```

## Checking Customer Trial Or Subscribed Status

For paid features of your app, you'll often want to check if the user is on trial OR subscribed. You can use this method to check both at once:

```ruby
@user.payment_processor.on_trial_or_subscribed?
```

You can also check for a specific subscription or plan:

```ruby
@user.payment_processor.on_trial_or_subscribed?(name: "default", processor_plan: "annual")
```

## Subscription API

Individual subscriptions provide similar helper methods to check their state.

#### Checking a Subscription's Trial Status

```ruby
@user.payment_processor.subscription.on_trial? #=> true or false
```

#### Checking a Subscription's Cancellation Status

```ruby
@user.payment_processor.subscription.cancelled? #=> true or false
```

#### Checking if a Subscription is on Grace Period

```ruby
@user.payment_processor.subscription.on_grace_period? #=> true or false
```

#### Checking if a Subscription is Active

```ruby
@user.payment_processor.subscription.active? #=> true or false
```

#### Checking if a Subscription is Paused

```ruby
@user.payment_processor.subscription.paused? #=> true or false
```

#### Cancel a Subscription (At End of Billing Cycle)

```ruby
@user.payment_processor.subscription.cancel
```

##### Paddle

In addition to the API, Paddle provides a subscription [Cancel URL](https://developer.paddle.com/guides/how-tos/subscriptions/cancel-and-pause) that you can redirect customers to cancel their subscription.

```ruby
@user.payment_processor.subscription.paddle_cancel_url
```

#### Cancel a Subscription Immediately

```ruby
@user.payment_processor.subscription.cancel_now!
```

#### Pause a Subscription (Paddle only)

```ruby
@user.payment_processor.subscription.pause
```

#### Swap a Subscription to another Plan

If a user wishes to change subscription plans, you can pass in the Plan or Price ID into the `swap` method:

```ruby
@user.payment_processor.subscription.swap("yearly")
```

Braintree does not allow this via their API, so we cancel and create a new subscription for you (including proration discount).

#### Resume a Subscription

A user may wish to resume their canceled (or paused) subscription. You can resume a subscription with:

```ruby
@user.payment_processor.subscription.resume
```

##### Stripe or Braintree Subscription (on Grace Period)

With Stripe or Braintree, a subscription on grace period may be resumed:

##### Paddle (Paused)

With Paddle, you may resume a paused subscription:

#### Retrieving the raw Subscription object from the Processor

```ruby
@user.payment_processor.subscription.processor_subscription
#=> #<Stripe::Subscription>
```

## Manually syncing subscriptions

In general, you don't need to use these methods as Pay's webhooks will keep you all your subscriptions in sync automatically.

However, for instance, a user returning from Stripe Checkout / Stripe Billing Portal might still see stale subscription information before the Webhook is processed, so these might come in handy. 

### Individual subscription

```rb
@user.payment_processor.subscription.sync!
```

### All at once

There's a convenience method for syncing all subscriptions at once (currently Stripe only).

```rb
@user.payment_processor.sync_subscriptions
```

As per Stripe's docs [here](https://stripe.com/docs/api/subscriptions/list?lang=ruby), by default the list of subscriptions **will not included canceled ones**. You can, however, retrieve them like this:

```rb
@user.payment_processor.sync_subscriptions(status: "all")
```

Since subscriptions views are not frequently accessed by users, you might accept to trade off some latency for increased safety on these views, avoiding showing stale data. For instance, in your controller:

```rb
class SubscriptionsController < ApplicationController

  def show
    # This guarantees your user will always see up-to-date subscription info
    # when returning from Stripe Checkout / Billing Portal, regardless of
    # webhooks race conditions.
    current_user.payment_processor.sync_subscriptions(status: "all")
  end

  def create
    # Let's say your business model doesn't allow multiple subscriptions per
    # user, and you want to make extra sure they are not already subscribed before showing the new subscription form.
    current_user.payment_processor.sync_subscriptions(status: "all")
    
    redirect_to subscription_path and return if current_user.payment_processor.subscription.active?
  end
```

## Next

See [Webhooks](7_webhooks.md)
