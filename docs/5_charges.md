# Charges

Pay allows you to make one-time charges to a customer.

## Creating a Charge

To charge a customer, you need to assign a payment method token before you can charge them.

```ruby
@user.payment_processor.update_payment_method(params[:payment_method_token])
@user.payment_processor.charge(15_00) # $15.00 USD
```

The `charge` method takes the amount in cents as the primary argument.

You may pass optional arguments that will be directly passed on to the payment processor. For example, you can use these options to charge different currencies:

```ruby
@user.payment_processor.charge(15_00, currency: "cad")
```

Amounts are in the currency's smallest unit, so zero-decimal currencies like JPY use whole yen: `charge(1000, currency: "jpy")` is ¥1,000.

Braintree charges in your merchant account's currency and doesn't take a `currency` option. Pay uses it only to convert the amount, so pass it when your merchant account isn't in a two-decimal currency.

On failure, a `Pay::Error` will be raised with details about the payment failure.

##### Paddle Classic Charges

When creating charges with Paddle, they need to be approved by the customer. This is done by
passing the Paddle Transaction ID to a Paddle.js checkout.

To see the required fields, see the [Paddle API docs](https://developer.paddle.com/api-reference/transactions/create-transaction).

The amount can be set to 0 as this will be set by the Price set on Paddle, so will be ignored.

```ruby
@user.payment_processor.charge(0, {
  items: [
    {
      quantity: 1,
      price_id: "pri_abc123"
    }
  ],
  # include additional fields here
})
```

Then you can set the `transactionId` attribute for Paddle.js. For more info, see the [Paddle.js docs](https://developer.paddle.com/paddlejs/methods/paddle-checkout-open)

##### Paddle Classic Charges

Paddle Classic requires an active subscription on the customer in order to create a one-time charge. It also requires a `charge_name` for the charge.

```ruby
@user.payment_processor.charge(1500, {charge_name: "Test"}) # $15.00 USD
```

##### Lemon Squeezy Charges

Lemon Squeezy currently doesn't support one-time charges.

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

### Paddle Billing Refunds

Paddle Billing refunds need approval from Paddle, so `refund!` returns the `Paddle::Adjustment` (with a `status` of `pending_approval`) and leaves `amount_refunded` alone. Once Paddle approves the refund, the `adjustment.updated` webhook syncs the charge and records it in `amount_refunded`. Paddle rejects new refunds on a transaction while one is still pending approval.

Paddle requires a reason for every refund. It defaults to `I18n.t("pay.refund")` and you can pass your own:

```ruby
charge.refund!(5_00, reason: "Customer request")
```

Refunding the full amount of a charge that has no refunds refunds the whole transaction. Partial refunds, including refunding what's left after a partial refund, are made against the transaction's line item, so they raise `Pay::PaddleBilling::Error` for transactions with more than one line item. Use the [Paddle API](https://developer.paddle.com/api-reference/adjustments/create-adjustment) directly to choose which items to refund. `refund!` checks what's left against the refunds Paddle has approved, so it's correct even before the webhook syncs a refund. Refunding more than what's left raises `Pay::PaddleBilling::Error`.

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

## Paddle Receipts

Paddle Billing doesn't provide a receipt URL like Paddle Classic did.

In order to retrieve a PDF invoice for a transaction, an API request is required. This will return a URL to the PDF invoice. This URL is not permanent and will expire after a short period of time.

```ruby
Paddle::Transaction.invoice(id: @charge.processor_id)
```

## Next

See [Subscriptions](6_subscriptions.md)
