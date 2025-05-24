# Stripe Connect

You can use Stripe Connect to handle Marketplace payments in your app.

There are two main marketplace payment types:

- Allow other businesses to accept payments directly from their customers (i.e. Shopify)
- Collect payments directly and pay out service providers separately (i.e. Lyft, Instacart, Postmates)

Not sure what account types to use? Read the Stripe docs: https://stripe.com/docs/connect/accounts

## Usage

To add Merchant functionality to a model, configure the model:

```ruby
class User
  pay_merchant
end
```

## Example

```ruby
@user = User.last

# Use Stripe for the Merchant
@user.set_merchant_processor :stripe

@user.merchant_processor.create_account
#=> Stripe::Account

@user.merchant_processor.account_link(refresh_url: your_url, return_url: your_url)
@user.merchant_processor.login_link
@user.merchant_processor.transfer(amount: 25_00)
@user.merchant_processor.onboarding_complete? # Updates via webhook based on the Stripe::Account's #charges_enabled attribute
```

## When Using Checkout Session

You can add your stripe connect account by passing the connect id to the set_payment_processor

```ruby
class SubscriptionsController < ApplicationController
  def checkout
    # Make sure the user's payment processor is Stripe
    current_user.set_payment_processor :stripe, stripe_account: "acct_1234"

    # One-time payments (https://stripe.com/docs/payments/accept-a-payment)
    @checkout_session = current_user.pay_payment_processor.checkout(mode: "payment", line_items: "price_1ILVZaKXBGcbgpbZQ26kgXWG")

    # Or Subscriptions (https://stripe.com/docs/billing/subscriptions/build-subscription)
    @checkout_session = current_user.pay_payment_processor.checkout(
      mode: 'subscription',
      locale: I18n.locale,
      line_items: [{
        price: 'price_1ILVZaKXBGcbgpbZQ26kgXWG',
        quantity: 4
      }],
      subscription_data: {
        trial_period_days: 15,
        metadata: {
          pay_name: "base" # Optional. Overrides the Pay::Subscription name attribute
        },
      },
      success_url: root_url,
      cancel_url: root_url
    )

    # Or Setup a new card for future use (https://stripe.com/docs/payments/save-and-reuse)
    @checkout_session = current_user.pay_payment_processor.checkout(mode: "setup")

    # If you want to redirect directly to checkout
    redirect_to @checkout_session.url, allow_other_host: true, status: :see_other
  end
end
```

## Charge Types

Stripe provides multiple ways of handling payments

| Charge Type                    | Use When                                                                                                                                                 |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Direct charges                 | Customers directly transact with your user, often unaware of your platform's existence                                                                   |
| Destination charges            | Customers transact with your platform for products or services provided by your user                                                                     |
| Separate charges and transfers | Multiple users are involved in the transaction <br />A specific user isn't known at the time of charge<br />Transfer can't be made at the time of charge |

### Direct Charges

- You create a charge on your user’s account so the payment appears as a charge on the connected account, not in your account balance.
- The connected account’s balance increases with every charge.
- Your account balance increases with application fees from every charge.
- The connected account’s balance will be debited for the cost of Stripe fees, refunds, and chargebacks.

```ruby
@user.stripe_account = "acct_123l5jadsgfas3"
@user.charge(10_00, application_fee_amount: 1_23)
```

```javascript
var stripe = Stripe("<%= @sample_credentials.test_publishable_key %>", {
  stripeAccount: "{{CONNECTED_STRIPE_ACCOUNT_ID}}",
});
```

### Destination Charges

- You create a charge on your platform’s account so the payment appears as a charge on your account. Then, you determine whether some or all of those funds are transferred to the connected account.
- Your account balance will be debited for the cost of the Stripe fees, refunds, and chargebacks.

```ruby
@user.charge(
  10_00,
  application_fee_amount: 1_23,
  transfer_data: {
    destination: '{{CONNECTED_STRIPE_ACCOUNT_ID}}'
  }
)
```

### Separate Charges and Transfers

- You create a charge on your platform’s account and also transfer funds to your user’s account. The payment appears as a charge on your account and there’s also a transfer to a connected account (amount determined by you), which is withdrawn from your account balance.
- You can transfer funds to multiple connected accounts.
- Your account balance will be debited for the cost of the Stripe fees, refunds, and chargebacks.

```ruby
pay_charge = @user.charge(100_00, transfer_group: '{ORDER10}')

# Create a Transfer to a connected account (later):
@other_user.merchant_processor.transfer(
  amount: 70_00,
  transfer_group: '{ORDER10}',
)

# Create a second Transfer to another connected account (later):
@another_user.merchant_processor.transfer(
  amount: 20_00,
  transfer_group: '{ORDER10}',
)
```

Alternatively, the `source_transaction` parameter allows you to transfer only once a charge's funds are available. This helps to make sure the funds are available in your Stripe account before transferring.

See: https://stripe.com/docs/connect/charges-transfers#transfer-availability

```ruby
@other_user.merchant_processor.transfer(
  amount: 70_00,
  source_transaction: pay_charge.processor_id
)
```

### Verification

By default, Pay sets up a webhook listener for the `account.updated` event that updates an `onboarding_complete` flag based on whether `charges_enabled` is true, which Stripe updates based on the account's current verification (or lack thereof) status as long as you request a charge or transfer capability when connecting the user's Stripe Connect account to your platform's Stripe account.
