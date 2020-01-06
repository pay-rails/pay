<p align="center"><img src="logo.png"></p>

## Pay

### Payments engine for Ruby on Rails

[![Build Status](https://github.com/excid3/pay/workflows/Tests/badge.svg)](https://github.com/excid3/pay/actions)

Pay is a payments engine for Ruby on Rails 4.2 and higher.

**Current Payment Providers**

- Stripe (API version [2018-08-23](https://stripe.com/docs/upgrades#2018-08-23) or higher required)
- Braintree

Want to add a new payment provider? Contributions are welcome and the instructions [are here](https://github.com/jasoncharnes/pay/wiki/New-Payment-Provider).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pay'

# To use Stripe, also include:
gem 'stripe', '< 5.0', '>= 2.8'
gem 'stripe_event', '~> 2.2'

# To use Braintree + PayPal, also include:
gem 'braintree', '< 3.0', '>= 2.92.0'

# To use Receipts
gem 'receipts', '~> 0.2.2'
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install pay
```

## Setup

#### Migrations

This engine will create a subscription model and the neccessary migrations for the model you want to make "billable." The most common use case for the billable model is a User.

To add the migrations to your application, run the following migration:

`$ bin/rails pay:install:migrations`

This will install three migrations:

- db/migrate/create_subscriptions.pay.rb
- db/migrate/add_fields_to_users.pay.rb
- db/migrate/create_charges.pay.rb

#### The User Model

If you have a `User` model defined in `app/models/user.rb` Pay will add the fields it needs to the `users` table.

If you do not have a `User` model defined, Pay will create a `users` table and you will need to add `app/models/user.rb`.

#### Non-User Model

If you need to use a model other than `User`, check out the [wiki page](https://github.com/jasoncharnes/pay/wiki/Model-Other-Than-User).

#### Run the Migrations

Finally, run the migrations with `$ rake db:migrate`

#### Getting NoMethodError?

`NoMethodError (undefined method 'stripe_customer' for #<User:0x00007fbc34b9bf20>)`

Fully restart your Rails application `bin/spring stop && rails s`

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

#### Background jobs

If a user's email is updated and they have a `processor_id` set, Pay will enqueue a background job (EmailSyncJob) to sync the email with the payment processor.

It's important you set a queue_adapter for this to happen. If you don't, the code will be executed immediately upon user update. [More information here](https://guides.rubyonrails.org/v4.2/active_job_basics.html#backends)

## Usage

Include the `Pay::Billable` module in the model you want to know about subscriptions.

```ruby
# app/models/user.rb
class User < ActiveRecord::Base
  include Pay::Billable
end
```

To sync over customer names, your `Billable` model should respond to the `first_name` and `last_name` methods. Pay will sync these over to your Customer objects in Stripe and Braintree.

## Configuration

Need to make some changes to how Pay is used? You can create an initializer `config/initializers/pay.rb`

```ruby
Pay.setup do |config|
  config.billable_class = 'User'
  config.billable_table = 'users'

  config.chargeable_class = 'Pay::Charge'
  config.chargeable_table = 'pay_charges'

  # For use in the receipt/refund/renewal mailers
  config.business_name = "Business Name"
  config.business_address = "1600 Pennsylvania Avenue NW"
  config.application_name = "My App"
  config.support_email = "helpme@example.com"

  config.send_emails = true

  config.automount_webhook_routes = true
  config.webhooks_path = "/webhooks" # Only when automount_webhook_routes is true
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

### Generators

#### Email Templates

If you want to modify the email templates, you can copy over the view files using:

```
$ bin/rails generate pay:email_views
```

## Emails

### Stripe

Emails can be enabled/disabled using the `send_emails` configuration option (enabled per default). When enabled, the following emails will be sent:

- When a charge succeeded
- When a charge was refunded
- When a subscription is about to renew

## User API

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

```ruby
user = User.find_by(email: 'michael@bluthcompany.co')

user.processor = 'stripe'
user.card_token = 'stripe-token'
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

#### Creating a Subscription

```ruby
user = User.find_by(email: 'michael@bluthcompany.co')

user.processor = 'stripe'
user.card_token = 'stripe-token'
user.subscribe
```

A `card_token` must be provided as an attribute.

The subscribe method has three optional arguments with default values.

```ruby
def subscribe(name: 'default', plan: 'default', **options)
  ...
end
```

##### Name

Name is an internally used name for the subscription.

##### Plan

Plan is the plan ID from the payment processor.

##### Options

They do something?

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

```ruby
user = User.find_by(email: 'george.michael@bluthcompany.co')

user.customer #> Stripe or Braintree customer account
```

#### Updating a Customer's Credit Card

```ruby
user = User.find_by(email: 'tobias@bluthcompany.co')

user.update_card('stripe-token')
```

#### Retrieving a Customer's Subscription from the Processor

```ruby
user = User.find_by(email: 'lucille@bluthcompany.co')

user.processor_subscription(subscription_id) #=> Stripe or Braintree Subscription
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

#### Cancel a Subscription (At End of Billing Cycle)

```ruby
user = User.find_by(email: 'oscar@bluthcompany.co')

user.subscription.cancel
```

#### Cancel a Subscription Immediately

```ruby
user = User.find_by(email: 'annyong@bluthcompany.co')

user.subscription.cancel_now!
```

#### Swap a Subscription to another Plan

```ruby
user = User.find_by(email: 'steve.holt@bluthcompany.co')

user.subscription.swap("yearly")
```

#### Resume a Subscription on a Grace Period

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

## Webhooks

Webhooks are automatically mounted to `/webhooks/{provider}`.

#### Customizing webhook mount path

If you have a catch all route (for 404s etc) and need to control where/when the webhook endpoints mount, you will need to disable automatic mounting and mount the engine above your catch all route.

```ruby
# config/initializers/pay.rb
config.automount_webhook_routes = false

# config/routes.rb
mount Pay::Engine, at: '/secret-webhook-path'
```

If you just want to modify where the engine mounts it's routes then you can change the path.

```ruby
# config/initializers/pay.rb

config.webhooks_path = '/secret-webhook-path'
```

## Contributors

- [Jason Charnes](https://twitter.com/jmcharnes)
- [Chris Oliver](https://twitter.com/excid3)

## Contributing

👋 Thanks for your interest in contributing. Feel free to fork this repo.

If you have an issue you'd like to submit, please do so using the issue tracker in GitHub. In order for us to help you in the best way possible, please be as detailed as you can.

If you'd like to open a PR please make sure the following things pass:

- `rake test`

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
