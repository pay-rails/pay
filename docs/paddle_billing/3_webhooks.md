# Paddle Billing Webhooks

## Endpoint

The webhook endpoint for Paddle Billing is `/pay/webhooks/paddle_billing` by default.

## Events

Pay requires the following webhooks to properly sync charges and subscriptions as they happen.

```ruby
subscription.activated
subscription.canceled
subscription.created
subscription.imported
subscription.past_due
subscription.paused
subscription.resumed
subscription.trialing
subscription.updated

transaction.completed

adjustment.created
adjustment.updated
```

The adjustment events record refunds on charges once Paddle approves them. Refunds that are still pending approval or were rejected don't change `amount_refunded`.
