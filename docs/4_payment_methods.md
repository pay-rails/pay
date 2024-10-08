# Payment Methods

The first thing you'll need to do is add a payment method. You will get a payment method token from the payment processor's Javascript library. See the payment processors docs for how to setup their Javascript.

## Updating the default Payment Method

To update the default payment method on file, you can use `update_payment_method`:

```ruby
@user.payment_processor.update_payment_method(params[:payment_method_token])
```

This will add the payment method via the API and mark it as the default for future payments.

##### Paddle Billing

For updating payment method details on Paddle, a transaction ID is required. This can be generated by using:

```ruby
subscription = @user.payment_processor.subscription(name: "plan name")
transaction  = subscription.payment_method_transaction
```

Once you have a transaction ID, you can then pass that through to Paddle.js like so

```html
<a href="#"
  class="paddle_button"
  data-display-mode="overlay"
  data-theme="light"
  data-locale="en"
  data-transaction-id="<%= transaction.id %>"
>
	Update Payment Details
</a>
```

This will then open the Paddle overlay and allow the user to update their payment details.

For more information, [see the Paddle documentation](https://developer.paddle.com/build/subscriptions/update-payment-details)

##### Paddle Classic

Paddle uses an [Update Payment Details URL](https://developer.paddle.com/guides/how-tos/subscriptions/update-payment-details) for each customer which allows them to update the payment method. This is stored on the `Pay::Subscription` record for easy access.

```ruby
@user.payment_processor.subscription.paddle_update_url
```

You may either redirect to this URL or use Paddle's Javascript to render as an overlay or inline.

##### Lemon Squeezy

Much like Paddle, Lemon Squeezy uses an Update Payment Details URL for each customer which allows them to update
the payment method. This URL expires after 24 hours, so this method retrieves a new one from the API each time.

```ruby
@user.payment_processor.subscription.update_url
```

Lemon Squeezy also offer a [Customer Portal](https://www.lemonsqueezy.com/features/customer-portal) where customers
can manage their subscriptions and payment methods. You can link to this portal using the `portal_url` method.
Just like the Update URL, this URL expires after 24 hours, so this method retrieves a new one from the API each time.

```ruby
@user.payment_processor.subscription.portal_url
```

You may either redirect to this URL or use Paddle's Javascript to render as an overlay or inline.

## Adding other Payment Methods

You can also add a payment method without making it the default.

```ruby
@user.payment_processor.add_payment_method(params[:payment_method_token], default: false)
```

## Importing Payment Methods

### Paddle Billing

If a Paymment Method doesn't exist in Pay, then you can use the following method to create it from Paddle Billing:

It takes a `Pay::Customer` and a Paddle Transaction ID as arguments.

```ruby
Pay::PaddleBilling::PaymentMethod.sync_from_transaction pay_customer: @user.payment_processor, transaction: "txn_abc123"
```

If a Payment Method already exists with the token, then it will be updated with the latest details from Paddle.

## Next

See [Charges](5_charges.md)

