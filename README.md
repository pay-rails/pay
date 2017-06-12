# Pay
Pay is a subscription engine for Ruby on Rails.

Supports Ruby on Rails 4.2 and higher.

**Current Payment Providers**
* Stripe

**Payment Providers In-Progress**
* Braintree

Want to add a new payment provider? Contributions are welcome and the instructions [are here](https://github.com/jasoncharnes/pay/wiki/New-Payment-Provider).

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'pay'
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

This will install two migrations:
- db/migrate/create_subscriptions.rb
- db/migrate/add_fields_to_users.rb

#### Non-User Model
If you need to use a model other than `User`, check out the [wiki page](https://github.com/jasoncharnes/pay/wiki/Model-Other-Than-User).

#### Run the Migrations
Finally, run the migrations with `$ rake db:migrate`

#### Stripe
You'll need to add your private Stripe API key to your Rails secrets. `config/secrets.yml`

```yaml
development:
  stripe_api_key: sk_test_....
```

## Usage
Include the `Pay::Billable` module in the model you want to know about subscriptions.

```ruby
# app/models/user.rb
class User < ActiveRecord::Base
  include Pay::Billable
end
```

**To see how to use Stripe Elements JS & Devise, [click here](https://github.com/jasoncharnes/pay/wiki/Using-Stripe-Elements-and-Devise).**

## User API
#### Creating a Subscription

```ruby
user = User.find_by(email: 'michael@bluthcompany.co')
user.card_token = 'stripe-token'
user.subscribe
```

A `card_token` must be provided as an attribute.

The subscribe method has three optional arguments with default values.

```ruby
def subscribe(name = 'default', plan = 'default', processor = 'stripe')
  ...
end
```

##### Name
Name is an internally used name for the subscription.

##### Plan
Plan is the plan ID from the payment processor.

#### Retrieving a Subscription from the Database
```ruby
user = User.find_by(email: 'gob@bluthcompany.co')
user.subscription
```

#### Checking a User's Subscription Status

```ruby
user = User.find_by(email: 'george.senior@bluthcompany.co')
user.subscribed?
```

The `subscribed?` method has two optional arguments with default values.

```ruby
def subscribed?(name = 'default', plan = nil)
  ...
end
```

##### Name
Name is an internally used name for the subscription.

##### Plan
Plan is the plan ID from the payment processor.

##### Processor
Processor is the string value of the payment processor subscription. Pay currently only supports Stripe, but other implementations are welcome.

#### Retrieving a Payment Processor Account

```ruby
user = User.find_by(email: 'george.michael@bluthcompany.co')
user.customer
```

#### Updating a Customer's Credit Card

```ruby
user = User.find_by(email: 'tobias@bluthcompany.co')
user.update_card('stripe-token')
```

#### Retrieving a Customer's Subscription from the Processor

```ruby
user = User.find_by(email: 'lucille@bluthcompany.co')
user.processor_subscription(subscription_id)
```

## Subscription API
#### Checking a Subscription's Trial Status

```ruby
user = User.find_by(email: 'lindsay@bluthcompany.co')
user.subscription.on_trial?
```

#### Checking a Subscription's Cancellation Status

```ruby
user = User.find_by(email: 'buster@bluthcompany.co')
user.subscription.cancelled?
```

#### Checking a Subscription's Grace Period Status

```ruby
user = User.find_by(email: 'her?@bluthcompany.co')
user.subscription.on_grace_period?
```

#### Checking to See If a Subscription Is Active

```ruby
user = User.find_by(email: 'carl.weathers@bluthcompany.co')
user.subscription.active?
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

## Contributors
* [Jason Charnes](https://twitter.com/jmcharnes)
* [Chris Oliver](https://twitter.com/excid3)

## Contributing
👋 Thanks for your interest in contributing. Feel free to fork this repo.

If you have an issue you'd like to submit, please do so using the issue tracker in GitHub. In order for us to help you in the best way possible, please be as detailed as you can.

If you'd like to open a PR please make sure the following things pass:
* `rake test`
* `rubocop`

These will need to be passing in order for a Pull Request to be accepted.

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
