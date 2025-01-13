# Stripe Webhooks

Pay listens to Stripe's webhooks to keep the local payments data in sync. 

For development, we use the Stripe CLI to forward webhooks to our local server. 
In production, webhooks are sent directly to our app's domain.

## Development webhooks with the Stripe CLI

You can use the [Stripe CLI](https://stripe.com/docs/stripe-cli) to test and forward webhooks in development.

```bash
stripe login
stripe listen --forward-to localhost:3000/pay/webhooks/stripe
```

## Production webhooks for Stripe

1. Visit https://dashboard.stripe.com/webhooks/create.
2. Use the default "Add an endpoint" form.
3. Set "endpoint URL" to https://example.org/pay/webhooks/stripe (Replace `example.org` with your domain)
4. Under "select events to listen to" choose "Select all events" and click "Add events". Or if you want to listen to specific events, check out [events we listen to](#events).
5. Finalize the creation of the endpoint by clicking "Add endpoint".
6. After creating the webhook endpoint, click "Reveal" under the heading "Signing secret". Copy the `whsec_... ` value to wherever you have configured your keys for Stripe as instructed in [Credentials](/docs/2_configuration.md#credentials) section under Configurations doc.

## Events

Pay requires the following webhooks to properly sync charges and subscriptions as they happen.

```ruby
charge.succeeded
charge.refunded

payment_intent.succeeded

invoice.upcoming
invoice.payment_action_required

customer.subscription.created
customer.subscription.updated
customer.subscription.deleted
customer.subscription.trial_will_end
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

[Click here](https://dashboard.stripe.com/webhooks/create?events=charge.succeeded%2Ccharge.refunded%2Cpayment_intent.succeeded%2Cinvoice.upcoming%2Cinvoice.payment_action_required%2Ccustomer.subscription.created%2Ccustomer.subscription.updated%2Ccustomer.subscription.deleted%2Ccustomer.subscription.trial_will_end%2Ccustomer.updated%2Ccustomer.deleted%2Cpayment_method.attached%2Cpayment_method.updated%2Cpayment_method.automatically_updated%2Cpayment_method.detached%2Caccount.updated%2Ccheckout.session.completed%2Ccheckout.session.async_payment_succeeded) to create a new Stripe webhook with all the events pre-filled.

## Next

See [Metered Billing](6_metered_billing.md)
