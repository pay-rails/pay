# Routes & Webhooks

Routes are automatically mounted to `/pay` by default.

## Stripe SCA Confirm Page

We provide a route for confirming Stripe SCA payments at `/pay/payments/:payment_intent_id`

See [Stripe SCA docs](stripe/4_sca.md)

## Webhooks

Pay comes with a bunch of different webhook handlers built-in. Each payment processor has different requirements for handling webhooks and we've implemented all the basic ones for you.

### Routes

Webhooks are automatically mounted at `/pay/webhooks/:provider`

To configure webhooks on your payment processor, use the following URLs (with your domain):

* **Stripe** - `https://example.org/pay/webhooks/stripe`
* **Braintree** - `https://example.org/pay/webhooks/braintree`
* **Paddle** - `https://example.org/pay/webhooks/paddle`

#### Mount path

If you have a catch all route (for 404s, etc) and need to control where/when the webhook endpoints mount, you will need to disable automatic mounting and mount the engine above your catch all route.

```ruby
# config/initializers/pay.rb
config.automount_routes = false
```

```ruby
# config/routes.rb
mount Pay::Engine, at: '/other-path'
```

If you just want to modify where the engine mounts it's routes then you can change the path.

```ruby
# config/initializers/pay.rb
config.routes_path = '/other-path'
```

### Event Naming

Since we support multiple payment providers, each event type is prefixed with the payment provider:

```ruby
"stripe.charge.succeeded"
"braintree.subscription_charged_successfully"
"paddle.subscription_created"
```

## Custom Webhook Listeners

To add your own webhook listener, you can simply subscribe to the event type.

```ruby
Pay::Webhooks.delegator.subscribe "stripe.charge.succeeded", MyChargeSucceededProcessor.new

class MyChargeSucceededProcessor
  def call(event)
    # do your processing here
  end
end
```

### Unsubscribing from a webhook listener

Need to unsubscribe or disable one of the default webhook processors? Simply unsubscribe from the event name:

```ruby
Pay::Webhooks.delegator.unsubscribe "stripe.charge.succeeded"
```

## Stripe CLI

The Stripe CLI lets you forward webhooks to your local Rails server during development. See the [Stripe Webhooks](stripe/5_webhooks.md) docs on how to use it.

## Next

See [Customizing Models](8_customizing_models.md)
