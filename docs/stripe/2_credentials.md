# Credentials

### API keys

You can find your Stripe private (secret) and pubilc (publishable) keys in the [Stripe Dashboard](https://dashboard.stripe.com/test/apikeys).

### Signing secrets

#### Dashbaord

Each webhook endpoint has it's own signing secret that you can reveal on the [Webhook detail page](https://dashboard.stripe.com/test/webhooks/).

#### Stripe CLI

View the webhook signing secret used by the Stripe CLI by running:

```sh
stripe listen --print-secret
```

## Next

See [JavaScript](3_javascript.md)
