# Stripe Webhooks

## Enable Stripe Webhooks

1. Visit https://dashboard.stripe.com/test/webhooks/create.
2. Use the default "Add an endpoint" form.
3. Set "endpoint URL" to https://example.org.ngrok.io/pay/webhooks/stripe (See [ngrok configurations](#ngrok) below).
4. Under "select events to listen to" choose "Select all events" and click "Add events". Or if you want to listen to specific events, check out [events we listen to](#events).
5. Finalize the creation of the endpoint by clicking "Add endpoint".

> [!TIP]
> 
> - `example.org` should be replaced with your own domain OR if you are using free version of ngrok then it might be something like `8dbc-2411-1a90-b012-d3c3-e1a0-edc8-f5d4-7a41.ngrok-free.app`.
> - In production / live app, "endpoint URL" should just be `https://example.org/pay/webhooks/stripe`
> - `pay/webhooks/stripe` is the route where you have mounted the pay gem as per the instructions in [Webhook Routes](/docs/7_webhooks.md#routes)

## Signing secrets

After creating the webhook endpoint, click "Reveal" under the heading "Signing secret". Copy the `whsec_... ` value to wherever you have configured your keys for Stripe as instructed in [Credentials](/docs/2_configuration.md#credentials) section under Configurations doc.

## Development

### Ngrok

Stripe provides free tooling ([Stripe CLI](#stripe-cli)) for receiving webhooks in your local environment. But you can also use NGROK for this. It provides a way to replicate all webhook operations similar to production environment since Stripe will be calling actual URL which makes it less prone to errors in production.

To enable ngrok, follow the steps belows:

1. Register your free (or paid) account with [ngrok](https://dashboard.ngrok.com/signup)
2. Point ngrok to your localhost `ngrok http http://localhost:3000` OR `ngrok http --domain=example.org 3000` if you registered for paid account

_NOTE_: Don't forget to have your Rails server (`rails s`) running as well when testing webhooks!

### Stripe CLI

You can use the [Stripe CLI](https://stripe.com/docs/stripe-cli) to test and forward webhooks in development.

You can enable the Stripe CLI from [Listen to Stripe events](https://dashboard.stripe.com/test/webhooks/create?endpoint_location=local) page. 

```bash
stripe listen --forward-to localhost:3000/pay/webhooks/stripe
```

>[!NOTE]
>
> By default we're linking to the "test mode" page for API keys so you can get up and running in development. When you're ready to deploy to production, you'll have to toggle the "test mode" option off and repeat all steps again for live payments.

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

## Next

See [Metered Billing](6_metered_billing.md)
