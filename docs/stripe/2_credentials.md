# Stripe Credentials

To use Stripe with Pay, you'll need to add your API keys and Signing Secret(s) to your Rails app. See [Configuring Pay](/docs/2_configuration.md#credentials) for instructions on adding credentials or ENV Vars.

### API keys

You can create (or find) your Stripe private (secret) and public (publishable) keys in the [Stripe Dashboard](https://dashboard.stripe.com/test/apikeys).

>[!NOTE]
>
> By default we're linking to the "test mode" page for API keys so you can get up and running in development. When you're ready to deploy to production, you'll have to toggle the "test mode" option off and repeat all steps again for live payments.

### Organization API keys (optional)

If you run several businesses under one [Stripe Organization](https://docs.stripe.com/get-started/account/orgs), you can use a single [organization API key](https://docs.stripe.com/keys/organization-api-keys) (`sk_org_…`) as `private_key` instead of a per-account secret key. Org keys require every request to identify the target account, so also set the optional `context` credential to that account's ID:

```yaml
stripe:
  private_key: sk_org_xxxx
  context: acct_xxxx
  # public_key and signing_secret are still per-account
```

(Or `ENV["STRIPE_CONTEXT"]`.) Pay passes it to stripe-ruby, which sends the `Stripe-Context` header on every request. With a regular account key, leave `context` unset — nothing changes.

Note: publishable keys and webhook signing secrets remain per-account (organizations can't accept client-side payments), so `public_key` and `signing_secret` stay as they are.

### Signing secrets

Webhooks use signing secrets to verify the webhook was sent by Stripe. Check out [Webhooks](/docs/stripe/5_webhooks.md#enable-stripe-webhooks) doc for detailed instructions on where/how to get these.

#### Dashboard

The [Webhooks](https://dashboard.stripe.com/test/webhooks/) page on Stripe contains all the defined endpoints and their signing secrets.

#### Stripe CLI (Development)

View the webhook signing secret used by the Stripe CLI by running:

```sh
stripe listen --print-secret
```

## Next

See [JavaScript](3_javascript.md)
