# Stripe Webhooks

Pay requires the following webhooks to properly sync charges and subscriptions as they happen.

```customer.subscription.updated
charge.succeeded
charge.refunded

payment_intent.succeeded

invoice.upcoming
invoice.payment_action-required

customer.subscription.created
customer.subscription.updated
customer.subscriptoin.deleted
customer.updated
customer.deleted

payment_method.attached
payment_method.updated
payment_method.card_automatically_updated
payment_method.detached

account.updated

checkout.session.completed
checkout.session.async_payment_succeeded
```

