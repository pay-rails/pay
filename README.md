# Pay
Pay is a Stripe subscription engine for Ruby on Rails.

Supports Ruby on Rails 4.2 and higher.

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

If you're using a model other than `User`, you can tell the Pay to change the billable class by adding the following file to your initializers:

```ruby
# config/initializers/pay.rb
Pay.setup do |config|
  config.billable_class = 'Company'
end
```

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

## API

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
