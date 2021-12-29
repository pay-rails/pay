# Stripe Credentials

To use Stripe with Pay, you'll need to add your API keys and Signing Secret(s) to your Rails app. See [Configuring Pay](/docs/2_configuration.md#credentials) for instructions on adding credentials or ENV Vars.

### API keys

You can find your Stripe private (secret) and pubilc (publishable) keys in the [Stripe Dashboard](https://dashboard.stripe.com/test/apikeys).

### Signing secrets

Webhooks use signing secrets to verify the webhook was sent by Stripe. You can find these on your Stripe Dashboard or the Stripe CLI.

#### Dashboard

The [Webhooks](https://dashboard.stripe.com/test/webhooks/) page on Stripe contains all the defined endpoints and their signing secrets.

#### Stripe CLI (Development)

View the webhook signing secret used by the Stripe CLI by running:

```sh
stripe listen --print-secret
```

## Next

See [JavaScript](3_javascript.md)
