<p align="center"><img src="docs/images/logo.svg" height="50px"></p>

## Pay - Payments engine for Ruby on Rails

[![Build Status](https://github.com/pay-rails/pay/workflows/Tests/badge.svg)](https://github.com/pay-rails/pay/actions) [![Gem Version](https://badge.fury.io/rb/pay.svg)](https://badge.fury.io/rb/pay)

<img src="docs/images/stripe_partner_badge.svg" height="26px">

Pay is a payments engine for Ruby on Rails 4.2 and higher.

**Current Payment Providers**

- Stripe ([SCA Compatible](https://stripe.com/docs/strong-customer-authentication) using API version `2020-08-27`)
- Paddle (SCA Compatible & supports PayPal)
- Braintree (supports PayPal)
- [Fake Processor](docs/fake_processor.md)

Want to add a new payment provider? Contributions are welcome and the instructions [are here](https://github.com/jasoncharnes/pay/wiki/New-Payment-Provider).

**Check the CHANGELOG for any required migrations or changes needed if you're upgrading from a previous version of Pay.**

## Tutorial

Want to see how Pay works? Check out our video getting started guide.

<a href="https://www.youtube.com/watch?v=hYlOmqyJIgc" target="_blank"><img width="50%" src="http://i3.ytimg.com/vi/hYlOmqyJIgc/maxresdefault.jpg"></a>

## Installation

Add these lines to your application's Gemfile:

```ruby
gem 'pay', '~> 2.0'

# To use Stripe, also include:
gem 'stripe', '< 6.0', '>= 2.8'

# To use Braintree + PayPal, also include:
gem 'braintree', '< 3.0', '>= 2.92.0'

# To use Paddle, also include:
gem 'paddle_pay', '~> 0.1'

# To use Receipts
gem 'receipts', '~> 1.0.0'
```

And then execute:

```bash
bundle
```

Next, we need to add migrations to your application, run the following migration:

````bash
bin/rails pay:install:migrations
````

>If your models rely on non integer ids (uuids for example) you will need to alter the `create_pay_subscriptions` and `create_pay_charges` migrations.

We also need to run migrations to add Pay to the User, Account, Team, etc models that we want to make payments in our app.

```bash
bin/rails g pay:billable User
```

This will generate a migration to add Pay fields to our User model and automatically includes the `Pay::Billable` module in our `User` model. Repeat this for all the models you want to make payments in your app.

**Note:** An `email` attribute or method on your `Billable` model is required.

To sync customer names, your `Billable` model should respond to the `first_name` and `last_name` methods. Pay will sync these over to your Customer objects in Stripe and Braintree.

Finally, run the migrations

```bash
bin/rails db:migrate
```

> If you run into `NoMethodError (undefined method 'stripe_customer' for #<User:0x00007fbc34b9bf20>)`, fully restart your Rails application `bin/spring stop && rails s`

Lastly, make sure you've configured your ActionMailer default_url_options so Pay can generate links to for features like Stripe Checkout.

```ruby
# config/application.rb
config.action_mailer.default_url_options = { host: "example.com" }
```

## Configuration

Need to make some changes to how Pay is used? You can create an initializer `config/initializers/pay.rb`

```ruby
Pay.setup do |config|
  # config.chargeable_class = 'Pay::Charge'
  # config.chargeable_table = 'pay_charges'

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

This allows you to create your own Charge class for instance, which could add receipt functionality:

```ruby
class Charge < Pay::Charge
  def receipts
    # do some receipts stuff using the https://github.com/excid3/receipts gem
  end
end

Pay.setup do |config|
  config.chargeable_class = 'Charge'
end
```

### Credentials

Pay automatically looks up credentials for each payment provider. We recommend storing them in the Rails credentials.

##### Rails Credentials & Secrets

You'll need to add your API keys to your Rails credentials. You can do this by running:

```bash
bin/rails credentials:edit --environment=development
```

They should be formatted like the following:

```yaml
stripe:
  private_key: sk_test_xxxx
  public_key: pk_test_yyyy
  signing_secret: whsec_zzzz

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
    private_key: sk_test_xxxx
    public_key: pk_test_yyyy
    signing_secret: whsec_zzzz
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

### Generators

If you want to modify the Stripe SCA template or any other views, you can copy over the view files using:

```bash
bin/rails generate pay:views
```

If you want to modify the email templates, you can copy over the view files using:

```bash
bin/rails generate pay:email_views
```

### Emails

Emails can be enabled/disabled using the `send_emails` configuration option (enabled by default).

When enabled, the following emails will be sent when:

- A charge succeeded
- A charge was refunded
- A subscription is about to renew


## Billable API

#### Trials

You can check if the user is on a trial by simply asking:

```ruby
user = User.find_by(email: 'michael@bluthcompany.co')

user.on_trial? #=> true or false
```

The `on_trial?` method has two optional arguments with default values.

```ruby
user = User.find_by(email: 'michael@bluthcompany.co')

user.on_trial?(name: 'default', plan: 'plan') #=> true or false
```

#### Generic Trials

For trials that don't require cards upfront:

```ruby
user = User.create(
  email: 'michael@bluthcompany.co',
  trial_ends_at: 30.days.from_now
)

user.on_generic_trial? #=> true
```

#### Creating a Charge

##### Stripe and Braintree

```ruby
user = User.find_by(email: 'michael@bluthcompany.co')

user.processor = 'stripe'
user.card_token = 'payment_method_id'
user.charge(1500) # $15.00 USD

user = User.find_by(email: 'michael@bluthcompany.co')

user.processor = 'braintree'
user.card_token = 'nonce'
user.charge(1500) # $15.00 USD
```

The `charge` method takes the amount in cents as the primary argument.

You may pass optional arguments that will be directly passed on to
either Stripe or Braintree. You can use these options to charge
different currencies, etc.

On failure, a `Pay::Error` will be raised with details about the payment
failure.

##### Paddle
It is only possible to create immediate one-time charges on top of an existing subscription.

```ruby
user = User.find_by(email: 'michael@bluthcompany.co')

user.processor = 'paddle'
user.charge(1500, {charge_name: "Test"}) # $15.00 USD

```

An existing subscription and a charge name are required.

#### Creating a Subscription

##### Stripe and Braintree

```ruby
user = User.find_by(email: 'michael@bluthcompany.co')

user.processor = 'stripe'
user.card_token = 'payment_method_id'
user.subscribe
```

A `card_token` must be provided as an attribute.

The subscribe method has three optional arguments with default values.

```ruby
def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
  ...
end
```

For example, you can pass the `quantity` option to subscribe to a plan with for per-seat pricing.

```ruby

user.subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, quantity: 3)
```

###### Name

Name is an internally used name for the subscription.

###### Plan

Plan is the plan ID or price ID from the payment processor. For example: `plan_xxxxx` or `price_xxxxx`

###### Options

By default, the trial specified on the subscription will be used.

`trial_period_days: 30` can be set to override and a trial to the subscription. This works the same for Braintree and Stripe.

##### Paddle
It is currently not possible to create a subscription through the API. Instead the subscription in Pay is created by the Paddle Subscription Webhook. In order to be able to assign the subcription to the correct owner, the Paddle [passthrough parameter](https://developer.paddle.com/guides/how-tos/checkout/pass-parameters) has to be used for checkout.

To ensure that the owner cannot be tampered with, Pay uses a Signed Global ID with a purpose. The purpose string consists of "paddle_" and the subscription plan id (or product id respectively).

Javascript Checkout:
```javascript
Paddle.Checkout.open({
	product: 12345,
	passthrough: "<%= Pay::Paddle.passthrough(owner: current_user) %>"
});
```

Paddle Button Checkout:
```html
<a href="#!" class="paddle_button" data-product="12345" data-email="<%= current_user.email %>" data-passthrough="<%= Pay::Paddle.passthrough(owner: current_user) %>"
```

###### Passthrough

Pay providers a helper method for generating the passthrough JSON object to associate the purchase with the correct Rails model.

```ruby
Pay::Paddle.passthrough(owner: current_user, foo: :bar)
#=> { owner_sgid: "xxxxxxxx", foo: "bar" }

# To generate manually without the helper
#=> { owner_sgid: current_user.to_sgid.to_s, foo: "bar" }.to_json
```

Pay parses the passthrough JSON string and verifies the `owner_sgid` hash to match the webhook with the correct billable record.
The passthrough parameter `owner_sgid` is only required for creating a subscription.

#### Retrieving a Subscription from the Database

```ruby
user = User.find_by(email: 'gob@bluthcompany.co')

user.subscription
```

A subscription can be retrieved by name, too.

```ruby
user = User.find_by(email: 'gob@bluthcompany.co')

user.subscription(name: 'bananastand+')
```

#### Checking a User's Trial/Subscription Status

```ruby
user = User.find_by(email: 'george.senior@bluthcompany.co')
user.on_trial_or_subscribed?
```

The `on_trial_or_subscribed?` method has two optional arguments with default values.

```ruby
def on_trial_or_subscribed?(name: 'default', plan: nil)
  ...
end
```

#### Checking a User's Subscription Status

```ruby
user = User.find_by(email: 'george.senior@bluthcompany.co')
user.subscribed?
```

The `subscribed?` method has two optional arguments with default values.

```ruby
def subscribed?(name: 'default', plan: nil)
  ...
end
```

##### Name

Name is an internally used name for the subscription.

##### Plan

Plan is the plan ID from the payment processor.

#### Retrieving a Payment Processor Account

##### Stripe and Braintree

```ruby
user = User.find_by(email: 'george.michael@bluthcompany.co')

user.customer #> Stripe or Braintree customer account
```

##### Paddle

It is currently not possible to retrieve a payment processor account through the API.

#### Updating a Customer's Credit Card

##### Stripe and Braintree

```ruby
user = User.find_by(email: 'tobias@bluthcompany.co')

user.update_card('payment_method_id')
```

##### Paddle

Paddle provides a unique [Update URL](https://developer.paddle.com/guides/how-tos/subscriptions/update-payment-details) for each user, which allows them to update the payment method.
```ruby
user = User.find_by(email: 'tobias@bluthcompany.co')

user.subscription.paddle_update_url
```



#### Retrieving a Customer's Subscription from the Processor

```ruby
user = User.find_by(email: 'lucille@bluthcompany.co')

user.processor_subscription(subscription_id) #=> Stripe, Braintree or Paddle Subscription
```

## Subscription API

#### Checking a Subscription's Trial Status

```ruby
user = User.find_by(email: 'lindsay@bluthcompany.co')

user.subscription.on_trial? #=> true or false
```

#### Checking a Subscription's Cancellation Status

```ruby
user = User.find_by(email: 'buster@bluthcompany.co')

user.subscription.cancelled? #=> true or false
```

#### Checking a Subscription's Grace Period Status

```ruby
user = User.find_by(email: 'her?@bluthcompany.co')

user.subscription.on_grace_period? #=> true or false
```

#### Checking to See If a Subscription Is Active

```ruby
user = User.find_by(email: 'carl.weathers@bluthcompany.co')

user.subscription.active? #=> true or false
```

#### Checking to See If a Subscription Is Paused

```ruby
user = User.find_by(email: 'carl.weathers@bluthcompany.co')

user.subscription.paused? #=> true or false
```

#### Cancel a Subscription (At End of Billing Cycle)

##### Stripe, Braintree and Paddle

```ruby
user = User.find_by(email: 'oscar@bluthcompany.co')

user.subscription.cancel
```

##### Paddle
In addition to the API, Paddle provides a subscription [Cancel URL](https://developer.paddle.com/guides/how-tos/subscriptions/cancel-and-pause) that you can redirect customers to cancel their subscription.

```ruby
user.subscription.paddle_cancel_url
```

#### Cancel a Subscription Immediately

```ruby
user = User.find_by(email: 'annyong@bluthcompany.co')

user.subscription.cancel_now!
```

#### Pause a Subscription

##### Paddle

```ruby
user = User.find_by(email: 'oscar@bluthcompany.co')

user.subscription.pause
```

#### Swap a Subscription to another Plan

```ruby
user = User.find_by(email: 'steve.holt@bluthcompany.co')

user.subscription.swap("yearly")
```

#### Resume a Subscription

##### Stripe or Braintree Subscription (on Grace Period)

```ruby
user = User.find_by(email: 'steve.holt@bluthcompany.co')

user.subscription.resume
```

##### Paddle (Paused)

```ruby
user = User.find_by(email: 'steve.holt@bluthcompany.co')

user.subscription.resume
```

#### Retrieving the Subscription from the Processor

```ruby
user = User.find_by(email: 'lucille2@bluthcompany.co')

user.subscription.processor_subscription
```

### Customizing Pay Models

Want to add methods to `Pay::Subscription` or `Pay::Charge`? You can
define a concern and simply include it in the model when Rails loads the
code.

Pay uses the `to_prepare` method to allow concerns to be
included every time Rails reloads the models in development as well.

```ruby
# app/models/concerns/subscription_extensions.rb
module SubscriptionExtensions
  extend ActiveSupport::Concern

  included do
    # associations and other class level things go here
  end

  # instance methods and code go here
end
```

```ruby
# config/initializers/subscription_extensions.rb

# Re-include the SubscriptionExtensions every time Rails reloads
Rails.application.config.to_prepare do
  Pay.subscription_model.include SubscriptionExtensions
end
```

## Routes & Webhooks

Routes are automatically mounted to `/pay` by default.

We provide a route for confirming SCA payments at `/pay/payments/:payment_intent_id`

Webhooks are automatically mounted at `/pay/webhooks/{provider}`

#### Customizing webhook mount path

If you have a catch all route (for 404s etc) and need to control where/when the webhook endpoints mount, you will need to disable automatic mounting and mount the engine above your catch all route.

```ruby
# config/initializers/pay.rb
Pay.setup do |config|
  # ...

  config.automount_routes = false
end

# config/routes.rb
Rails.application.routes.draw do
  mount Pay::Engine, at: '/pay' # You can change the `at` path to feed your needs.

  # Other routes here
end
```

If you just want to modify where the engine mounts it's routes then you can change the path.

```ruby
# config/initializers/pay.rb

Pay.setup do |config|
  # ...

  config.routes_path = '/pay'
end
```

## Payment Providers

We support Stripe, Braintree and Paddle and make our best attempt to
standardize the three. They function differently so keep that in mind if
you plan on doing more complex payments. It would be best to stick with
a single payment provider in that case so you don't run into
discrepancies.

#### Braintree

```yaml
development:
  braintree:
    private_key: xxxx
    public_key: yyyy
    merchant_id: zzzz
    environment: sandbox
```
#### Paddle

```yaml
  paddle:
    vendor_id: xxxx
    vendor_auth_code: yyyy
    public_key_base64: MII...==
    environment: sandbox
```

Paddle receipts can be retrieved by a charge receipt URL.
```ruby
user = User.find_by(email: 'annyong@bluthcompany.co')

charge = user.charges.first
charge.paddle_receipt_url
```
#### Stripe

You'll need to add your private Stripe API key to your Rails secrets `config/secrets.yml`, credentials `rails credentials:edit`

```yaml
development:
  stripe:
    private_key: xxxx
    public_key: yyyy
    signing_secret: zzzz
```

You can also use the `STRIPE_PRIVATE_KEY` and `STRIPE_SIGNING_SECRET` environment variables.

**To see how to use Stripe Elements JS & Devise, [click here](https://github.com/jasoncharnes/pay/wiki/Using-Stripe-Elements-and-Devise).**

You need the following event types to trigger the webhook:

```
customer.subscription.updated
customer.subscription.deleted
customer.subscription.created
payment_method.updated
invoice.payment_action_required
customer.updated
customer.deleted
charge.succeeded
charge.refunded
```

##### Strong Customer Authentication (SCA)

Our Stripe integration **requires** the use of Payment Method objects to correctly support Strong Customer Authentication with Stripe. If you've previously been using card tokens, you'll need to upgrade your Javascript integration.

Subscriptions that require SCA are marked as `incomplete` by default.
Once payment is authenticated, Stripe will send a webhook updating the
status of the subscription. You'll need to use the [Stripe CLI](https://github.com/stripe/stripe-cli) to forward
webhooks to your application to make sure your subscriptions work
correctly for SCA payments.

```bash
stripe listen --forward-to localhost:3000/pay/webhooks/stripe
```

You should use `stripe.confirmCardSetup` on the client to collect card information anytime you want to save the card and charge them later (adding a card, then charging them on the next page for example). Use `stripe.confirmCardPayment` if you'd like to charge the customer immediately (think checking out of a shopping cart).

The Javascript also needs to have a PaymentIntent or SetupIntent created server-side and the ID passed into the Javascript to do this. That way it knows how to safely handle the card tokenization if it meets the SCA requirements.

**Payment Confirmations**

Sometimes you'll have a payment that requires extra authentication. In this case, Pay provides a webhook and action for handling these payments. It will automatically email the customer and provide a link with the PaymentIntent ID in the url where the customer will be asked to fill out their name and card number to confirm the payment. Once done, they'll be redirected back to your application.

If you'd like to change the views of the payment confirmation page, you can install the views using the generator and modify the template.

[<img src="https://d1jfzjx68gj8xs.cloudfront.net/items/2s3Z0J3Z3b1J1v2K2O1a/Screen%20Shot%202019-10-10%20at%2012.56.32%20PM.png?X-CloudApp-Visitor-Id=51470" alt="Stripe SCA Payment Confirmation" style="zoom: 25%;" />](https://d1jfzjx68gj8xs.cloudfront.net/items/2s3Z0J3Z3b1J1v2K2O1a/Screen%20Shot%202019-10-10%20at%2012.56.32%20PM.png)

If you use the default views for payment confirmations, and also have a Content Security Policy in place for your application, make sure to add the following domains to their respective configurations in your `content_security_policy.rb` (otherwise these views won't load properly):

* `style_src`: `https://unpkg.com`
* `script_src`: `https://cdn.jsdelivr.net` and `https://js.stripe.com`
* `frame_src`: `https://js.stripe.com`

#### Background jobs

If a user's email is updated and they have a `processor_id` set, Pay will enqueue a background job (EmailSyncJob) to sync the email with the payment processor.

It's important you set a queue_adapter for this to happen. If you don't, the code will be executed immediately upon user update. [More information here](https://guides.rubyonrails.org/v4.2/active_job_basics.html#backends)


## Contributors

- [Jason Charnes](https://twitter.com/jmcharnes)
- [Chris Oliver](https://twitter.com/excid3)

## Contributing

👋 Thanks for your interest in contributing. Feel free to fork this repo.

If you have an issue you'd like to submit, please do so using the issue tracker in GitHub. In order for us to help you in the best way possible, please be as detailed as you can.

If you'd like to open a PR please make sure the following things pass:

```ruby
bin/rails db:test:prepare
bin/rails test
```

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
