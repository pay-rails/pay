# Installing Pay

Pay's installation is pretty straightforward. We'll add the gems, add some migrations, and update our models.

## Gemfile

Add these lines to your application's Gemfile:

```ruby
gem "pay", "~> 4.0"

# To use Stripe, also include:
gem "stripe", "~> 6.0"

# To use Braintree + PayPal, also include:
gem "braintree", "~> 4.7"

# To use Paddle, also include:
gem "paddle_pay", "~> 0.2"

# To use Receipts gem for creating invoice and receipt PDFs, also include:
gem "receipts", "~> 2.0"
```

And then execute:

```bash
bundle
```

## Migrations

Copy the Pay migrations to your app:

````bash
bin/rails pay:install:migrations
````

>If your models rely on non integer ids (uuids for example) you will need to alter the migrations.

Then run the migrations:

```bash
bin/rails db:migrate
```

Make sure you've configured your ActionMailer `default_url_options` so Pay can generate links (for features like Stripe Checkout).

```ruby
# config/application.rb
config.action_mailer.default_url_options = { host: "example.com" }
```

## Models

To add Pay to a model in your Rails app, simply add `pay_customer` to the model:

```ruby
# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           default(""), not null

class User < ApplicationRecord
  pay_customer
end
```

**Note:** Pay requires your model to have an `email` attribute. Email is a field that is required by Stripe, Braintree, etc to create a Customer record.

To sync customer names automatically to your payment processor, your model should respond to one of the following methods. Pay will sync these over to your Customer objects in Stripe and Braintree anytime they change.

* `name`
* `first_name` _and_ `last_name`
* `pay_customer_name`

### Customer Attributes

Stripe allows you to send over a hash of attributes to store in the Customer record in addition to email and name.

```ruby
class User < ApplicationRecord
  pay_customer stripe_attributes: :stripe_attributes
  # Or using a lambda:
  # pay_customer stripe_attributes: ->(pay_customer) { metadata: { { user_id: pay_customer.owner_id } } }

  def stripe_attributes(pay_customer)
    {
      address: {
        city: pay_customer.owner.city,
        country: pay_customer.owner.country
      },
      metadata: {
        pay_customer_id: pay_customer.id,
        user_id: id # or pay_customer.owner_id
      }
    }
  end
```

Pay will include attributes when creating a Customer and update them when the Customer is updated.

## Next

See [Configuration](2_configuration.md)
