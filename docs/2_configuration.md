# Configuring Pay

Pay comes with a lot of configuration out of the box for you, but you'll need to add your API tokens for your payment provider.

## Credentials

Pay automatically looks up credentials for each payment provider. We recommend storing them in the Rails credentials.

##### Rails Credentials & Secrets

You'll need to add your API keys to your Rails credentials. You can do this by running:

```bash
rails credentials:edit --environment=development
```

They should be formatted like the following:

```yaml
stripe:
  private_key: xxxx
  public_key: yyyy
  signing_secret:
  - aaaa
  - bbbb
braintree:
  private_key: xxxx
  public_key: yyyy
  merchant_id: aaaa
  environment: sandbox
paddle:
  vendor_id: xxxx
  vendor_auth_code: yyyy
  public_key_base64: MII...==
  environment: sandbox
```

You can also nest these credentials under the Rails environment if using a shared credentials file or secrets.

```yaml
development:
  stripe:
    private_key: xxxx
# ...
```

##### Environment Variables

Pay will also check environment variables for API keys:

* `STRIPE_PUBLIC_KEY`
* `STRIPE_PRIVATE_KEY`
* `STRIPE_SIGNING_SECRET`
* `BRAINTREE_MERCHANT_ID`
* `BRAINTREE_PUBLIC_KEY`
* `BRAINTREE_PRIVATE_KEY`
* `BRAINTREE_ENVIRONMENT`
* `PADDLE_VENDOR_ID`
* `PADDLE_VENDOR_AUTH_CODE`
* `PADDLE_PUBLIC_KEY_BASE64`
* `PADDLE_ENVIRONMENT`

## Generators

If you want to modify the Stripe SCA template or any other views, you can copy over the view files using:

```bash
bin/rails generate pay:views
```

If you want to modify the email templates, you can copy over the view files using:

```bash
bin/rails generate pay:email_views
```

## Emails

Emails can be enabled/disabled using the `send_emails` configuration option (enabled by default).

When enabled, the following emails will be sent when:

- A charge succeeded
- A charge was refunded
- A yearly subscription is about to renew

## Configuration

Need to make some changes to how Pay is used? You can create an initializer `config/initializers/pay.rb`

```ruby
Pay.setup do |config|
  # For use in the receipt/refund/renewal mailers
  config.business_name = "Business Name"
  config.business_address = "1600 Pennsylvania Avenue NW"
  config.application_name = "My App"
  config.support_email = "helpme@example.com"

  config.send_emails = true

  config.default_product_name = "default"
  config.default_plan_name = "default"

  config.automount_routes = true
  config.routes_path = "/pay" # Only when automount_routes is true
end
```

## Background jobs

If a user's email is updated, Pay will enqueue a background job (`CustomerSyncJob`) to sync the email with the payment processors they have setup.

It is important you set a queue_adapter for this to happen. If you don't, the code will be executed immediately upon user update. [More information here](https://guides.rubyonrails.org/v6.1/active_job_basics.html#backends)

```ruby
# config/application.rb
config.active_job.queue_adapter = :sidekiq
```

## Next

See [Customers](3_customers.md)

