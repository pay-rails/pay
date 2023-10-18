# Charges

Pay allows you to make one-time charges to a customer.

## Creating a Charge

To charge a customer, you need to assign a payment method token before you can charge them.

```ruby
@user.payment_processor.payment_method_token = params[:payment_method_token]
@user.payment_processor.charge(15_00) # $15.00 USD
```

The `charge` method takes the amount in cents as the primary argument.

You may pass optional arguments that will be directly passed on to the payment processor. For example, you can use these options to charge different currencies:

```ruby
@user.payment_processor.charge(15_00, currency: "cad")
```

On failure, a `Pay::Error` will be raised with details about the payment failure.

##### Paddle Classic Charges

Paddle Classic requires an active subscription on the customer in order to create a one-time charge. It also requires a `charge_name` for the charge.

```ruby
@user.payment_processor.charge(1500, {charge_name: "Test"}) # $15.00 USD
```

## Retrieving Charges

To see a list of charges for a customer, you can access them with:

```ruby
@user.payment_processor.charges
```

## Refunding A Charge

You can refund a charge by calling `refund!` on the charge:

```ruby
charge = @user.payment_processor.charges.last

# Refund the full amount
charge.refund!

# Partial refund of $5.00
charge.refund!(5_00)
```

## Payment Method

Charges record a copy of their payment method. This allows users to update their payment methods without losing the information on previous purchases.

The details saved will vary depending upon the payment method used.

```ruby
@charge.payment_method_type
#=> card, paypal, sepa, ideal, etc

@charge.brand
#=> Visa, Discover, MasterCard, American Express, PayPal, Venmo, etc

@charge.last4 #=> 4242
@charge.exp_month #=> 12
@charge.exp_year #=> 2021
@charge.email #=> PayPal email
@charge.username #=> Venmo username
@charge.bank #=> Bank name
```

## Receipt URL

Paddle Classic and Stripe provide a receipt URL for each payment.

```ruby
@charge.paddle_receipt_url
@charge.stripe_receipt_url
```

## Next

See [Subscriptions](6_subscriptions.md)
