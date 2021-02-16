# Using Pay with Stripe

Stripe has multiple integrations:

* Stripe Checkout - Hosted pages for payments

## Stripe Checkout

[Stripe Checkout](https://stripe.com/docs/payments/checkout) allows you to simply redirect to Stripe for handling payments. The main benefit is that it's super fast to setup payments in your application, they're SCA compatible, and they will get improved automatically by Stripe.

![stripe checkout example](https://i.imgur.com/nFsCBCK.gif)

### How to use Stripe Checkout with Pay

1. Create a checkout session

Choose the checkout button mode you need and pass any required arguments. Read the [Stripe Checkout Session API docs](https://stripe.com/docs/api/checkout/sessions/create) to see what options are available.

```ruby
# Make sure the user's payment processor is Stripe
current_user.processor = :stripe

# One-time payments
@checkout_session = current_user.payment_processor.checkout(mode: "payment", line_items: "price_1ILVZaKXBGcbgpbZQ26kgXWG")

# Subscriptions
@checkout_session = current_user.payment_processor.checkout(mode: "subscription", line_items: "default")

# Setup a new card for future use
@subscription = current_user.payment_processor.checkout(mode: "setup")
```

2. Render the button

```erb
<%= render partial: "pay/stripe/checkout_button", locals: { session: @checkout_session, title: "Checkout" } %>
```
