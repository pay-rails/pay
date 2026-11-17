# Stripe Strong Customer Authentication (SCA)

Some payments need the customer to authenticate, usually with 3D Secure, before they go through. How you handle that depends on where the payment is confirmed.

Once a payment is authenticated, Stripe sends webhooks that update the charge or subscription in Pay. In development, use the [Stripe CLI](https://github.com/stripe/stripe-cli) to forward them to your app:

```bash
stripe listen --forward-to localhost:3000/pay/webhooks/stripe
```

## Payments confirmed in the browser

If customers pay with [Stripe Checkout](8_stripe_checkout.md), or your page confirms the payment with the [Payment Element](https://docs.stripe.com/payments/payment-element) using `stripe.confirmPayment` or `stripe.confirmSetup` (see [JavaScript](3_javascript.md)), Stripe.js handles authentication right there. This is what Stripe recommends, and you don't need anything else.

## Payments confirmed on the server

`charge`, `subscribe`, `swap`, `resume` and `retry_failed_payment` confirm the payment on the server. When it can't complete, Pay raises an error with the payment attached as `e.payment`:

* `Pay::ActionRequired` when the customer needs to authenticate
* `Pay::InvalidPaymentMethod` when the customer needs to use a different payment method

### Pay's confirmation page

Pay includes a page at `/pay/payments/:id` that finishes either case. It uses the Payment Element, so the customer can authenticate or enter a new payment method, and it works for PaymentIntents and SetupIntents (for example, a trial's payment method).

```ruby
def create
  @user.payment_processor.charge(10_00)
  # or @user.payment_processor.subscribe(plan: "x")
  redirect_to dashboard_path

rescue Pay::ActionRequired, Pay::InvalidPaymentMethod => e
  # stripe_account is nil (and left out of the URL) unless the payment is on a Stripe Connect account
  # back is where the page's Back link goes
  redirect_to pay.payment_path(e.payment.id, stripe_account: e.payment.stripe_account, back: dashboard_path)

rescue Pay::Error => e
  flash[:alert] = e.message
  render :new, status: :unprocessable_entity
end
```

For a payment on a Stripe Connect account, Pay looks up the intent on that account and initializes Stripe.js with `stripeAccount`.

### Your own page

To keep the customer on your page, send `e.payment.client_secret` to the browser and call [`stripe.handleNextAction`](https://docs.stripe.com/js/payment_intents/handle_next_action), which works for PaymentIntents and SetupIntents:

```js
// stripeAccount is only needed for payments on a Stripe Connect account
const stripe = Stripe(publishableKey, stripeAccount ? { stripeAccount } : {})
const { error } = await stripe.handleNextAction({ clientSecret })
```

`handleNextAction` only handles authentication. If it fails, or for `Pay::InvalidPaymentMethod`, the customer needs a new payment method, so you'll need the Payment Element too. Pay's confirmation page is a good starting point (see [Customizing the confirmation page](#customizing-the-confirmation-page)).

## Payments made while the customer is away

When a subscription renewal needs authentication, Stripe sends the `invoice.payment_action_required` webhook and Pay emails the customer a link to the confirmation page. You can turn this off with `config.emails.payment_action_required`.

A one-off charge made while the customer is away, for example from a background job, has no invoice, so Pay doesn't send an email. If it needs authentication, let the customer know yourself and link them to `pay.payment_url(payment_intent_id)`, where they can authenticate or use a different payment method.

## Customizing the confirmation page

To change the confirmation page, copy Pay's views into your app and edit `app/views/pay/payments/show.html.erb`:

```bash
bin/rails generate pay:views
```

The page initializes Stripe.js with `Pay::Stripe.public_key`. If your app uses more than one Stripe account, change it to the publishable key for the payment's account.

If your app has a Content Security Policy, add these domains to your `content_security_policy.rb` for the default page:

* `style_src`: `https://unpkg.com`
* `script_src`: `https://unpkg.com` and `https://js.stripe.com`
* `frame_src`: `https://js.stripe.com`

## Next

See [Webhooks](5_webhooks.md)
