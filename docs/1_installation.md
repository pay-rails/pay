# Installing Pay

Pay's installation is pretty straightforward. We'll add the gems, add some migrations, and update our models.

## Gemfile

Add these lines to your application's Gemfile:

```ruby
gem "pay", "~> 7.0"

# To use Stripe, also include:
gem "stripe", "~> 11.0"

# To use Braintree + PayPal, also include:
gem "braintree", "~> 4.7"

# To use Paddle Billing or Paddle Classic, also include:
gem "paddle", "~> 2.1"

# To use Lemon Squeezy, also include:
gem "lemonsqueezy", "~> 1.0"

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

For pay to also send the customer's name to your payment processor, your model should respond to one of the following methods.

* `name`
* `first_name` _and_ `last_name`
* `pay_customer_name`

Name _will not_ sync automatically. See the section below _Syncing attributes_.

### Customer Attributes

Stripe allows you to send over a hash of attributes to store in the Customer record in addition to email and name.
For more information about the different attributes Stripe accepts for a customer visit the Stripe API documentation [here](https://stripe.com/docs/api/customers/object).

```ruby
class User < ApplicationRecord
  pay_customer stripe_attributes: :stripe_attributes
  # Or using a lambda:
  # pay_customer stripe_attributes: ->(pay_customer) { { metadata: { user_id: pay_customer.owner_id } } }

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

### Syncing attributes

By adding `pay_customer` to your model, the `Pay::Billable::SyncCustomer` concern will be included. It's responsible for syncing your customer's data from your application to the payment processor in an `after_commit` callback if the method `pay_should_sync_customer?` returns `true`.

By default, `pay_should_sync_customer?` will respond with `saved_change_to_email?`, which means Pay will automatically sync your customer with your payment processor when its e-mail changes.

If you want to automatically sync whenever any other attribute changes, override `pay_should_sync_customer?` in your model. For instance, if you want to sync when your model's name changes, or you are using `stripe_attributes` above to send Stripe the customer's address, it might be a good idea to also sync when these attributes change:

```rb
class User < ApplicationRecord

  def pay_should_sync_customer?
    # super will invoke Pay's default (e-mail changed)
    super || self.saved_change_to_address? || self.saved_change_to_name?
  end

end
```

[ActiveRecord Dirty](https://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/Dirty.html) is your friend here.

## Next

See [Configuration](2_configuration.md)
