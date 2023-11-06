# Using Pay with Paddle Billing

Paddle Billing is Paddle's new subscription billing platform. It differs quite a bit
from Paddle Classic. This guide will help you get started with implementing it in your
Rails application.

* Checkout only happens via iFrame or hosted page
* Cancelling a subscription cannot be resumed
* Payment methods can only be updated while a subscription is active

## Creating Customers

Paddle now works similar to Stripe. You create a customer, which subscriptions belong to.

```ruby
# Set the payment processor
@user.set_payment_processor :paddle_billing

# Create the customer on Paddle
@user.payment_processor.customer
```

## Prices & Plans

Paddle introduced Products & Prices to support more payment options. Previously,
they Products and Plans separated.

## Subscriptions

Paddle subscriptions are not created through the API, but through Webhooks. When a
subscription is created, Paddle will send a webhook to your application. Pay will
automatically create the subscription for you.

## Configuration

### Paddle API Key

You can generate an API key [here for Production](https://vendors.paddle.com/authentication-v2)
or [here for Sandbox](https://sandbox-vendors.paddle.com/authentication-v2)

### Paddle Client Token

Client side tokens are used to work with Paddle.js in your frontend. You can generate one using the same links above.

### Paddle Environment

Paddle has two environments: Sandbox and Production. To use the Sandbox environment,
set the Environment value to `sandbox`. By default, this is set to `production`.

### Paddle Signing Secret

Paddle uses a signing secret to verify that webhooks are coming from Paddle. You can find
this after creating a webhook in the Paddle dashboard. You'll find this page
[here for Production](https://vendors.paddle.com/notifications) or
[here for Sandbox](https://sandbox-vendors.paddle.com/notifications).

### Environment Variables

Pay will automatically look for the following environment variables, or the equivalent
Rails credentials:

- `PADDLE_BILLING_ENVIRONMENT`
- `PADDLE_BILLING_API_KEY`
- `PADDLE_BILLING_CLIENT_TOKEN`
- `PADDLE_BILLING_SIGNING_SECRET`
