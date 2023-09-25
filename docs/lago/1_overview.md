# Using Pay with Lago

Lago works somewhat differently than the other payment processors so it comes with some limitations and differences.

* Lago itself doesn't handle payments, but can be set up to trigger them through other services (Stripe etc.)
  - Currently Pay doesn't provide an interface for setting up payment processors in Lago.
  - Payment providers will have to be configured directly with the Lago API or UI.
* Lago subscriptions do not have trials etc.
* Charges are mapped to Lago invoices.
* Some features require [Lago Premium](https://www.getlago.com/pricing) to function correctly.
* Wherever Lago requires an external_id, Pay will use the [GlobalID](https://github.com/rails/globalid) of the corresponding Pay object.
  - This is unless the object already has processor_id set, in which case it'll use that.

## Configuration

Lago requires an API key for it's client to work. This can be found at [/developers]() on your Lago instance.

If you are using Lago self-hosted, you will also need to provide the url to your API instance.

```yaml
# Configuration for Lago in Rails Credentials.
lago:
  api_key: <YOUR API KEY>
  api_url: <YOUR API URL>
```

```bash
# Configuration for Lago in Environment Variables
LAGO_API_URL="<YOUR API URL>" LAGO_API_KEY="<YOUR API KEY>" rails server
```

If your configuration is correct, `Pay::Lago.valid_auth?` will be true.

## Using the Lago API Client

Pay automatically configures an instance of the Lago Client for use across the module. However, the same client can be accessed
for direct use of the [Lago API](https://docs.getlago.com/api-reference/intro).

The client instance can be accessed from `Pay::Lago.client`.

You can verify that your Lago

### Please Note:
For any API calls that would use a GET, the external_id must be [URI encoded](https://ruby-doc.org/current/stdlibs/uri/URI.html#method-c-encode_www_form_component), as the lago-ruby-client gem does not currently do this itself. See [this issue](https://github.com/getlago/lago-ruby-client/issues/136).