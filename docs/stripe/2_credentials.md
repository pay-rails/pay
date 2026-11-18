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

Pay makes every Stripe API request through a [`Stripe::StripeClient`](https://github.com/stripe/stripe-ruby#usage), which you can get with `Pay::Stripe.client`. For a Connect account, pass `{stripe_account: "acct_..."}` as the request options, like `Pay::Stripe.client.v1.customers.retrieve("cus_...", {}, {stripe_account: "acct_..."})`. By default it uses your global Stripe configuration (`Stripe.api_key`, `Stripe.api_base`, `Stripe.api_version`, and so on).

If your app uses more than one Stripe account (not [Connect](/docs/marketplaces/stripe_connect.md) accounts, which Pay handles itself), set `Pay::Stripe.client_options` to return the [`StripeClient` options](https://github.com/stripe/stripe-ruby#per-request-configuration) Pay should use. They're merged over your global configuration, and returning `nil` uses it unchanged. It's called for every request, so it can read whatever your app uses to track the current account:

```ruby
# config/initializers/pay.rb
Pay::Stripe.client_options = -> {
  {api_key: Current.brand.stripe_api_key} if Current.brand
}
```

Background jobs don't have `Current.brand` unless you set it there yourself, so Pay can also pass the `Pay::Customer` the request is for. Accept keyword arguments to get it, and keep `Current` as the fallback:

```ruby
Pay::Stripe.client_options = ->(customer: nil, **) {
  brand = customer&.owner&.brand || Current.brand
  {api_key: brand.stripe_api_key} if brand
}
```

Accept `**` so Pay can pass more context later without breaking your callable.

`customer` is set for calls on a customer, charge, subscription or payment method (`charge`, `subscribe`, `sync!`, `cancel`, `refund!` and so on), including those made in background jobs like `Pay::CustomerSyncJob`. It's `nil` when Pay doesn't know the customer yet, which is why the fallback matters:

* Syncs that start from an ID, like `Pay::Stripe::Charge.sync("ch_123")`, fetch the object before Pay can look up its customer. Requests after the lookup get the customer.
* Webhooks for a Stripe customer that isn't in Pay's database. Webhooks get the customer when Pay has it. Otherwise Pay can't tell which Stripe account sent the webhook, so `client_options` has to find the account itself. One way is to set `Current` in your own wrapper around `Pay::Webhooks::ProcessJob`.
* `Pay::Stripe.sync_checkout_session`, `Pay::Payment.from_id` without `customer:`, and `Pay::Stripe::Merchant` (Connect platform) calls.

Objects Pay fetches keep the API key they were fetched with, so later calls on them go to the same account. So do the objects Pay rebuilds from its database or a webhook, like `subscription.stripe_object`, the invoice on a charge's receipt and webhook events, so paging through their lists works too.

A few things to keep in mind:

* Pay sets the [Connect](/docs/marketplaces/stripe_connect.md) account itself from the customer, charge or subscription, so `client_options` can't return `stripe_account`. Pay raises an `ArgumentError` if it does.
* If your global configuration uses an [organization API key](#organization-api-keys-optional) with `context`, return `stripe_context: nil` alongside a regular account key so the `Stripe-Context` header isn't sent with it.
* `client_options` runs for every request, and some Pay methods make several. Cache anything slow to look up, for example in `Current`.
* `charge.stripe_object` is only rebuilt for reading its attributes, so it doesn't call `client_options`, and requests made from it use your global configuration.
* `client_options` only covers API requests. Pay's [SCA confirmation page](4_sca.md) uses `Pay::Stripe.public_key`, so copy its views with `bin/rails generate pay:views` and swap in the publishable key that matches the API key.
* Each Stripe account's webhook endpoint has its own signing secret. List them all under `signing_secret` in your Rails credentials, [as a YAML list](/docs/2_configuration.md#credentials), and Pay accepts a webhook that matches any of them. An `ENV` variable holds only one secret.

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
