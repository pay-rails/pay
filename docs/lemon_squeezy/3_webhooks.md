# Lemon Squeezy Webhooks

## Endpoint

The webhook endpoint for Lemon Squeezy is `/pay/webhooks/lemon_squeezy` by default.

## Events

Pay requires the following webhooks to properly sync charges and subscriptions as they happen.

```ruby
subscription_created
subscription_updated
subscription_payment_success
```
