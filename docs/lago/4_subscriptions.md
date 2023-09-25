# Subscriptions

## Adding a Subscription to a Customer

Customers can be subscribed to a plan using the `subscribe` method on Pay::Customer. Subscriptions should be given a name,
and must tie to an existing plan in Lago.

Plans can be created using the [Lago API](https://docs.getlago.com/api-reference/plans/create), or through the UI.

```ruby
# Subscribe a customer to the plan with code "my-plan"
customer = Pay::Customer.find(1234)
customer.subscribe(name: "My Subscription", plan: "my-plan")
```

```ruby
# Subscribe a customer to the plan, and provide additional attributes
customer = Pay::Customer.find(1234)
customer.subscribe(name: "My Subscription", plan: "my-plan", status: "active", billing_time: "calendar")
```

See [Lago Subscription API](https://docs.getlago.com/api-reference/subscriptions/assign-plan) for valid attributes.

## Cancelling a Subscription

Subscriptions can be cancelled using the `cancel` method on Pay::Subscription.

This will terminate the subscription in Lago, and a credit note will automatically be issued by Lago refunding the customer
for their remaining time on the subscription. See [Terminate a subscription](https://docs.getlago.com/guide/subscriptions/terminate-subscription).

```ruby
# Cancel a Subscription
subscription = Pay::Subscription.find(1234)
subscription.cancel
```

```ruby
# Cancel a Pending Subscription
subscription = Pay::Subscription.find(1234)
subscription.cancel(status: "pending")
```

## Changing a Subscription's Plan

You can change the plan of a subscription using the `swap` method on Pay::Subscription.

Given a plan code, this method will switch the plan over at time of the next invoice.

```ruby
# Switch a Subscription to "my-second-plan"
subscription = Pay::Subscription.find(1234)
subscription.swap("my-second-plan")
```

```ruby
# Switch a Subscription to "my-second-plan", and update some attributes
subscription = Pay::Subscription.find(1234)
subscription.swap("my-second-plan", name: "My Updated Subscription")
```

See [Lago Subscription API](https://docs.getlago.com/api-reference/subscriptions/assign-plan) for valid attributes.

## Trials, Pausing, Quantity etc.

Lago does not implement trial periods, pause/resume, quantities etc.

Pay will raise Pay::Lago::Error when attempting to use methods that would usually perform these functions.