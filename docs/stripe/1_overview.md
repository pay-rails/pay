# Using Pay with Stripe

Stripe has multiple options for payments

* Stripe Checkout - Hosted pages for payments (you'll redirect users to Stripe)
* Stripe Elements - Payment fields on your site

## Prices & Plans

Stripe introduced Products & Prices to support more payment options. Previously, they had a concept called Plan that was for subscriptions. Pay supports both Price IDs and Plan IDs when subscribing.

```ruby
@user.payment_processor.subscribe(plan: "price_1234")
@user.payment_processor.subscribe(plan: "plan_1234")
```

## Stripe Checkout

[Stripe Checkout](https://stripe.com/docs/payments/checkout) allows you to simply redirect to Stripe for handling payments. The main benefit is that it's super fast to setup payments in your application, they're SCA compatible, and they will get improved automatically by Stripe.

![stripe checkout example](https://i.imgur.com/nFsCBCK.gif)

### How to use Stripe Checkout with Pay

1. Create a checkout session

Choose the checkout button mode you need and pass any required arguments. Read the [Stripe Checkout Session API docs](https://stripe.com/docs/api/checkout/sessions/create) to see what options are available.

```ruby
# Make sure the user's payment processor is Stripe
current_user.set_payment_processor :stripe

# One-time payments
@checkout_session = current_user.payment_processor.checkout(mode: "payment", line_items: "price_1ILVZaKXBGcbgpbZQ26kgXWG")

# Subscriptions
@checkout_session = current_user.payment_processor.checkout(mode: "subscription", line_items: "default")

# Setup a new card for future use
@checkout_session = current_user.payment_processor.checkout(mode: "setup")
```

Success and cancel and cancel URLs are automatically generated for you and point to the root URL. To customize these, pass in the following options.

```ruby
@checkout_session = current_user.payment_processor.checkout(
  mode: "payment",
  line_items: "price_1ILVZaKXBGcbgpbZQ26kgXWG",
  success_url: root_url,
  cancel_url: root_url
)
```

The `session_id` param will be included on success and cancel URLs automatically. This allows you to lookup the checkout session on your success page and confirm the payment was successful before fulfilling the customer's purchase.

https://stripe.com/docs/payments/checkout/custom-success-page

2. Redirect or Render the button

If you want to redirect directly to checkout, simply redirect to the `url` on the session object.

```ruby
redirect_to @checkout_session.url
```

Alternatively, you can use Pay & Stripe.js to render a button that will take the user to Stripe Checkout.

```erb
<%= render partial: "pay/stripe/checkout_button", locals: { session: @checkout_session, title: "Checkout" } %>
```

3. Link to the Customer Billing Portal

Customers will want to update their payment method, subscription, etc. This can be done with the Customer Billing Portal. It works the same as the other Stripe Checkout pages.

First, create a session in your controller:

```ruby
@portal_session = current_user.payment_processor.billing_portal
```

Then link to it in your view

```erb
<%= link_to "Billing Portal", @portal_session.url %>
```

4. Fulfilling orders after Checkout completed

For one-time payments, you'll need to add a webhook listener for the Checkout `stripe.checkout.session.completed` and `stripe.checkout.session.async_payment_succeeded` events. Some payment methods are delayed so you need to verify the `payment_status == "paid"`. The async payment succeeded event fires when delayed payments are complete.

For subscriptions, Pay will automatically create the `Pay::Subscription` record for you.

```ruby
Pay::Webhooks.delegator.subscribe "stripe.checkout.session.completed", FulfillCheckout.new
Pay::Webhooks.delegator.subscribe "stripe.checkout.session.async_payment_succeeded", FulfillCheckout.new

class FulfillCheckout
  def call(event)
    object = event.data.object

    if object.payment_status == "paid"
      # Handle fulfillment
    end
  end
end
```

That's it!

## Next

See [Credentials](2_credentials.md)
