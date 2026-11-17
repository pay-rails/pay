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

### Multiple Stripe accounts (optional)

Pay makes every Stripe API request through a [`Stripe::StripeClient`](https://github.com/stripe/stripe-ruby#usage), which you can get with `Pay::Stripe.client` (or `Pay::Stripe.client(stripe_account: "acct_...")` for a Connect account). By default it uses your global Stripe configuration (`Stripe.api_key`, `Stripe.api_base`, `Stripe.api_version`, and so on).

If your app uses more than one Stripe account (not [Connect](/docs/marketplaces/stripe_connect.md) accounts, which Pay handles itself), set `Pay::Stripe.client_options` to return the [`StripeClient` options](https://github.com/stripe/stripe-ruby#per-request-configuration) Pay should use. They're merged over your global configuration. It's called for every request, so it can read whatever your app uses to track the current account:

```ruby
# config/initializers/pay.rb
Pay::Stripe.client_options = -> {
  {api_key: Current.account.stripe_api_key} if Current.account
}
```

Return `nil` to use the global configuration unchanged. Objects Pay fetches keep the API key they were fetched with, so later calls on them go to the same account. Pay still sets the Connect account for customers, charges and subscriptions that have one, overriding any `stripe_account` you return.

Pay doesn't record which account a customer or webhook belongs to, so `client_options` also has to return the right options in background jobs, including `Pay::Webhooks::ProcessJob`.

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
