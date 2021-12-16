# Stripe Webhooks

### Development

You can use the [Stripe CLI](https://stripe.com/docs/stripe-cli) to test and forward webhooks in development.

```bash
stripe listen --forward-to localhost:3000/pay/webhooks/stripe
```

### Events

Pay requires the following webhooks to properly sync charges and subscriptions as they happen.

```ruby
charge.succeeded
charge.refunded

payment_intent.succeeded

invoice.upcoming
invoice.payment_action_required

customer.subscription.created
customer.subscription.updated
customer.subscriptoin.deleted
customer.updated
customer.deleted

payment_method.attached
payment_method.updated
payment_method.automatically_updated
payment_method.detached

account.updated

checkout.session.completed
checkout.session.async_payment_succeeded
```
