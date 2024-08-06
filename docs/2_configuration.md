# Configuring Pay

Pay comes with a lot of configuration out of the box for you, but you'll need to add your API tokens for your payment provider.

## Credentials

Pay automatically looks up credentials for each payment provider. We recommend storing them in the Rails credentials.

##### Rails Credentials

You'll need to add your API keys to your Rails credentials. You can do this by running:

```bash
rails credentials:edit --environment=development
```

They should be formatted like the following:

```yaml
stripe:
  private_key: xxxx
  public_key: yyyy
  webhook_receive_test_events: true
  signing_secret:
  - aaaa
  - bbbb
braintree:
  private_key: xxxx
  public_key: yyyy
  merchant_id: aaaa
  environment: sandbox
paddle_billing:
  client_token: aaaa
  api_key: yyyy
  signing_secret: pdl_ntfset...
  environment: sandbox
paddle_classic:
  vendor_id: xxxx
  vendor_auth_code: yyyy
  public_key_base64: MII...==
  environment: sandbox
lemon_squeezy:
  api_key: xxxx
  store_id: yyyy
  signing_secret: aaaa
```

You can also nest these credentials under the Rails environment if using a shared credentials file.

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
* `STRIPE_WEBHOOK_RECEIVE_TEST_EVENTS`
* `BRAINTREE_MERCHANT_ID`
* `BRAINTREE_PUBLIC_KEY`
* `BRAINTREE_PRIVATE_KEY`
* `BRAINTREE_ENVIRONMENT`
* `PADDLE_BILLING_API_KEY`
* `PADDLE_BILLING_CLIENT_TOKEN`
* `PADDLE_BILLING_SIGNING_SECRET`
* `PADDLE_BILLING_ENVIRONMENT`
* `PADDLE_CLASSIC_VENDOR_ID`
* `PADDLE_CLASSIC_VENDOR_AUTH_CODE`
* `PADDLE_CLASSIC_PUBLIC_KEY`
* `PADDLE_CLASSIC_PUBLIC_KEY_FILE`
* `PADDLE_CLASSIC_PUBLIC_KEY_BASE64`
* `PADDLE_CLASSIC_ENVIRONMENT`
* `LEMON_SQUEEZY_API_KEY`
* `LEMON_SQUEEZY_STORE_ID`
* `LEMON_SQUEEZY_SIGNING_SECRET`

> [!TIP]
>
> Are you using any of these payment processors for the very first time? Take a look at their respective configuration doc for generating these keys:
>
> - [Stripe](/docs/stripe/2_credentials.md)
> - [Paddle Billing](/docs/paddle_billing/1_overview.md#configuration)
> - [Paddle Classic](/docs/paddle_classic/1_overview.md#paddle-public-key)

#### STRIPE_WEBHOOK_RECEIVE_TEST_EVENTS (Default to TRUE)
As per the guidance from https://support.stripe.com/questions/connect-account-webhook-configurations: "When a connected account is linked solely in live mode to your platform, both live and test events are sent to your live Connect Webhook Endpoint." Therefore, you can set this to false if you wish to receive only live events in Production.

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

Emails can be enabled/disabled as a whole by using the `send_emails` configuration option or independently by
using the `emails` configuration option as shown in the configuration section below (all emails are enabled by default).

When enabled, the following emails will be sent when:

- A payment action is required
- A payment failed
- A charge succeeded
- A charge was refunded
- A yearly subscription is about to renew
- A subscription trial is about to end
- A subscription trial has ended

## Configuration

Need to make some changes to how Pay is used? You can create an initializer `config/initializers/pay.rb`

```ruby
Pay.setup do |config|
  # For use in the receipt/refund/renewal mailers
  config.business_name = "Business Name"
  config.business_address = "1600 Pennsylvania Avenue NW"
  config.application_name = "My App"
  config.support_email = "Business Name <support@example.com>"

  config.default_product_name = "default"
  config.default_plan_name = "default"

  config.automount_routes = true
  config.routes_path = "/pay" # Only when automount_routes is true
  # All processors are enabled by default. If a processor is already implemented in your application, you can omit it from this list and the processor will not be set up through the Pay gem.
  config.enabled_processors = [:stripe, :braintree, :paddle_billing, :paddle_classic, :lemon_squeezy]

  # To disable all emails, set the following configuration option to false:
  config.send_emails = true

  # All emails can be configured independently as to whether to be sent or not. The values can be set to true, false or a custom lambda to set up more involved logic. The Pay defaults are show below and can be modified as needed.
  config.emails.payment_action_required = true
  config.emails.payment_failed = true
  config.emails.receipt = true
  config.emails.refund = true
  # This example for subscription_renewing only applies to Stripe, therefore we supply the second argument of price
  config.emails.subscription_renewing = ->(pay_subscription, price) {
    (price&.type == "recurring") && (price.recurring&.interval == "year")
  }
  config.emails.subscription_trial_will_end = true
  config.emails.subscription_trial_ended = true

  # Customize who receives emails. Useful when adding additional recipients other than the Pay::Customer. This defaults to the pay customer's email address.
  # config.mail_to = ->(mailer, params) { "#{params[:pay_customer].customer_name} <#{params[:pay_customer].email}>" }

  # Customize mail() arguments. By default, only includes { to: }. Useful when you want to add cc, bcc, customize the mail subject, etc.
  # config.mail_arguments = ->(mailer, params) {
  #   {
  #     to: Pay.mail_recipients.call(mailer, params)
  #   }
  # }
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
