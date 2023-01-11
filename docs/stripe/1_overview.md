# Using Pay with Stripe

Stripe has multiple options for payments

* [Stripe Checkout](https://stripe.com/payments/checkout) - Hosted pages for payments (you'll redirect users to Stripe)
* [Stripe Elements](https://stripe.com/payments/elements) - Payment fields on your site

## Prices & Plans

Stripe introduced Products & Prices to support more payment options. Previously, they had a concept called Plan that was for subscriptions. Pay supports both `Price IDs` and `Plan IDs` when subscribing.

```ruby
@user.payment_processor.subscribe(plan: "price_1234")
@user.payment_processor.subscribe(plan: "plan_1234")
```

Multiple subscription items in a single subscription can be passed in as `items`:

```ruby
@user.payment_processor.subscribe(
  items: [
    {price: "price_1234"},
    {price: "price_5678"}
  ]
)
```

See: https://stripe.com/docs/api/subscriptions/create

## Promotion Codes

Promotion codes are customer-facing coupon codes that can be applied in several ways.

You can apply a promotion code on the Stripe::Customer to have it automatically apply to all Subscriptions.

```ruby
@user.payment_processor.update_customer!(promotion_code: "promo_1234")
```

Promotion codes can also be applied directly to a subscription:
```ruby
@user.payment_processor.subscribe(plan: "plan_1234", promotion_code: "promo_1234")
```

Stripe Checkout can also accept promotion codes by enabling the flag:
```ruby
@checkout_session = current_user.payment_processor.checkout(
  mode: "payment",
  line_items: "price_1ILVZaKXBGcbgpbZQ26kgXWG",
  allow_promotion_codes: true
)
```

## Failed Payments

Subscriptions that fail payments will be set to `past_due` status.

If all attempts are exhausted, Stripe will either leave the subscription as `past_due`, `canceled`, or set it as `unpaid` depending on the settings in your Stripe account.

We recommend marking subscriptions as `unpaid`. Pay treats this subscription as inactive. You can display it and allow the user to pay their outstanding invoice in order to resume their subscription.

## Next

See [Credentials](2_credentials.md)
