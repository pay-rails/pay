# Paddle Webhooks

## Endpoint

The webhook endpoint for Paddle is `/pay/webhooks/paddle` by default.

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
```
