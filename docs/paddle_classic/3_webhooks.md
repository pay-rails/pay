# Paddle Classic Webhooks

## Endpoint

The webhook endpoint for Paddle is `/pay/webhooks/paddle_classic` by default.

## Events

Pay requires the following webhooks to properly sync charges and subscriptions as they happen.

```ruby
subscription_created
subscription_updated
subscription_cancelled
subscription_payment_succeeded
subscription_payment_refunded
```
