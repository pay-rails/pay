# Customers

Every payment processor has a Customer object that keeps track of your customers by email. Pay keeps track of these Customers with the `Pay::Customer` model.

## Setting the Payment Processor

Before you can process payments, you need to assign a payment processor for the user.

```ruby
@user.set_payment_processor :stripe
@user.set_payment_processor :braintree
@user.set_payment_processor :paddle
@user.set_payment_processor :fake_processor, allow_fake: true
```

This creates a `Pay::Customer` record in the database that keeps track of the payment processor's ID and allows you to interact with the API to charge and subscribe this customer.

The `fake_processor` is restricted by default so users can't give themselves free access to your application.

Alternatively, you can set a default processor for all users.

```ruby
class User < ApplicationRecord
  pay_customer default_payment_processor: :stripe
end
```

## Payment Processor Associations

After setting the payment processor, your model will have a `payment_processor` they can use to create charges, subscriptions, etc.

```ruby
@user.payment_processor
#=> #<Pay::Customer processor: "stripe", processor_id: "cus_1000">
```

This record keeps track of payment processor is active and the ID for the customer on the API. It also is associated with all Charges, Subscriptions, and Payment Methods.

A user might switch between payment processors. For example, they might initially subscribe using Braintree, cancel after a while, and resubscribe using Stripe later on.

Pay keeps track of these with a `has_many :pay_customers` association.

```ruby
@user.pay_customers
#=> [#<Pay::Customer>, #<Pay::Customer>]
```

Only one `Pay::Customer` can be the default which is used for `payment_processor`.

## Retrieving a Customer object from the Payment Processor

If you need to access the API object directly from the payment processor like the `Stripe::Customer`. You can retrieve the object with:

```ruby
@user.payment_processor.customer
#=> #<Stripe::Customer>
```

##### Paddle:

It is currently not possible to retrieve a Customer object through the Paddle API.

## Next

See [Payment Methods](4_payment_methods.md)
