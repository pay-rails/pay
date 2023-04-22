# Stripe Tax

Collecting tax is easy with Stripe and Pay. You'll need to enable Stripe Tax in the dashboard and configure your Tax registrations where you're required to collect tax.

### Set Address on Customer

An address is required on the Customer for tax calculations.

```ruby
class User < ApplicationRecord
  pay_customer stripe_attributes: :stripe_attributes

  def stripe_attributes(pay_customer)
    {
      address: {
        country: "US",
        postal_code: "90210"
      }
    }
  end
end
```

To update the customer address anytime it's changed, call the following method:

```ruby
@user.payment_processor.update_customer!
```

This will make an API request to update the Stripe::Customer with the current `stripe_attributes`.

See the Stripe Docs for more information about update tax addresses on a customer.
https://stripe.com/docs/api/customers/update#update_customer-tax-ip_address

### Subscribe with Automatic Tax

To enable tax for a subscription, you can pass in `automatic_tax`:

```ruby
@user.payment_processor.subscribe(plan: "growth", automatic_tax: { enabled: true })
```

For Stripe Checkout, you can do the same thing:

```ruby
@user.payment_processor.checkout(mode: "payment", line_items: "price_1234", automatic_tax: { enabled: true })
@user.payment_processor.checkout(mode: "subscription", line_items: "price_1234", automatic_tax: { enabled: true })
```

### Pay::Charges

Taxes are saved on the `Pay::Charge` model.

* `tax` - the total tax charged
* `total_tax_amounts` - The tax rates for each jurisidction on the charge

## Next

See [Stripe Checkout & Billing Portal](8_stripe_checkout.md)
