# Stripe Strong Customer Authentication (SCA)

Our Stripe integration **requires** the use of Payment Method objects to correctly support Strong Customer Authentication with Stripe. If you've previously been using card tokens, you'll need to upgrade your Javascript integration.

Subscriptions that require SCA are marked as `incomplete` by default.
Once payment is authenticated, Stripe will send a webhook updating the
status of the subscription. You'll need to use the [Stripe CLI](https://github.com/stripe/stripe-cli) to forward
webhooks to your application to make sure your subscriptions work
correctly for SCA payments.

```bash
stripe listen --forward-to localhost:3000/pay/webhooks/stripe
```

You should use `stripe.confirmCardSetup` on the client to collect card information anytime you want to save the card and charge them later (adding a card, then charging them on the next page for example). Use `stripe.confirmCardPayment` if you'd like to charge the customer immediately (think checking out of a shopping cart).

The Javascript also needs to have a PaymentIntent or SetupIntent created server-side and the ID passed into the Javascript to do this. That way it knows how to safely handle the card tokenization if it meets the SCA requirements.

## **SCA Payment Confirmations**

Sometimes you'll have a payment that requires extra authentication. In this case, Pay provides a webhook and action for handling these payments. It will automatically email the customer and provide a link with the PaymentIntent ID in the url where the customer will be asked to fill out their name and card number to confirm the payment. Once done, they'll be redirected back to your application.

### Pay::ActionRequired

When a charge or subscription needs SCA confirmation, Pay will raise a `Pay::ActionRequired` error. You can use this to redirect to the SCA confirm page.

```ruby
def create
  @user.charge(10_00)
  # or @user.subscribe(plan: "x")

rescue Pay::ActionRequired => e
  # Redirect to the Pay SCA confirmation page
  redirect_to pay.payment_path(e.payment.id)

rescue Pay::Error => e
  # Display any other errors
  flash[:alert] = e.message
  render :new, status: :unprocessable_entity
end
```

### Stripe SCA Confirm Page

We provide a route for confirming Stripe SCA payments at `/pay/payments/:payment_intent_id`.

If you'd like to change the views of the payment confirmation page, you can install the views using the generator and modify the template.

[<img src="https://d1jfzjx68gj8xs.cloudfront.net/items/2s3Z0J3Z3b1J1v2K2O1a/Screen%20Shot%202019-10-10%20at%2012.56.32%20PM.png?X-CloudApp-Visitor-Id=51470" alt="Stripe SCA Payment Confirmation" style="zoom: 25%;" />](https://d1jfzjx68gj8xs.cloudfront.net/items/2s3Z0J3Z3b1J1v2K2O1a/Screen%20Shot%202019-10-10%20at%2012.56.32%20PM.png)

If you use the default views for payment confirmations, and also have a Content Security Policy in place for your application, make sure to add the following domains to their respective configurations in your `content_security_policy.rb` (otherwise these views won't load properly):

* `style_src`: `https://unpkg.com`
* `script_src`: `https://unpkg.com` and `https://js.stripe.com`
* `frame_src`: `https://js.stripe.com`

## Next

See [Webhooks](5_webhooks.md)
