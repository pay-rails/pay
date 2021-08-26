# Payment Methods

The first thing you'll need to do is add a payment method. You will get a payment method token from the payment processor's Javascript library. See the payment processors docs for how to setup their Javascript.

## Assigning A Payment Method

With Pay, you can simply assign the payment method token before making a charge or subscription.

Pay will attempt to save an API request by creating a Customer and assigning PaymentMethod in the same request if a `payment_method_token` is set.

```ruby
@user.payment_processor.payment_method_token = params[:payment_method_token]
@user.payment_processor.charge(15_00)
```

The payment method will be set as the default, so future payments do not need to collect a payment method.

If a customer would like to purchase and provide a new payment method, you may still assign a `payment_method_token` before purchasing.

## Updating the default Payment Method

To update the default payment method on file, you can use  `update_payment_method`:

```ruby
@user.payment_processor.update_payment_method(params[:payment_method_token])
```

This will add the payment method via the API and mark it as the default for future payments.

##### Paddle

Paddle uses an [Update Payment Details URL](https://developer.paddle.com/guides/how-tos/subscriptions/update-payment-details) for each customer which allows them to update the payment method. This is stored on the `Pay::Subscription` record for easy access.

```ruby
@user.payment_processor.subscription.paddle_update_url
```

You may either redirect to this URL or use Paddle's Javascript to render as an overlay or inline.

## Adding other Payment Methods

You can also add a payment method without making it the default.

```ruby
@user.payment_processor.add_payment_method(params[:payment_method_token], default: false)
```

## Next

See [Charges](docs/5_charges.md)

