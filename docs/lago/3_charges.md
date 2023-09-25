# Charges

Lago itself does not create charges. Rather, it creates invoices, and triggers a charge through another service if configured.

Lago invoices will sync to Pay::Charges however, if the webhook is configured.

## Charging a Customer
Even though Lago doesn't necessarily support arbitrary charges, Pay implements somewhat of a workaround to maintain consistency.

Using the `charge` method on the Pay::Customer will function as a normal charge, taking an amount, then "charging" the customer
said amount.

This creates a [One-off Invoice](https://docs.getlago.com/guide/one-off-invoices/create-one-off-invoices) on Lago.

One-off Invoices require an add-on on Lago. Pay will automatically create a "default" add-on, and use that if no add-on is provided
to the `charge` method.

### Using your Own Add-ons
While not explicitly necessary, **it is best practise to use your own add-ons**.

Add-ons should provide meaningful information about the service to the invoice. Creating your own allows you to give it a nice name, and a description.

Create add-ons through the [API](https://docs.getlago.com/api-reference/add-ons/create), or by using the Lago UI.

You can provide your addon code to the `charge` method, for it to use that add-on instead.

```ruby
# Using an add-on with the charge method
customer = Pay::Customer.find(1234)
customer.charge(10_00, addon: "my-addon-code")
```

```ruby
# If you would like to add some attributes, pass an options hash.
# Note: currency must match the customer's currency.
customer = Pay::Customer.find(1234)
customer.charge(10_00, addon: "my-addon-code", options: { currency: "AUD" })
```

```ruby
# If you would like to use the amount defined in the add-on instead,
# set the charge amount to a falsey value.
customer = Pay::Customer.find(1234)
customer.charge(nil, addon: "my-addon-code")
```

## Updating a Lago Invoice
Lago Invoices can be updated by calling `update_charge!` on the Pay::Charge object. The method takes a Hash of attributes to be
changed, and returns a Lago Invoice [OpenStruct](https://ruby-doc.org/current/stdlibs/ostruct/OpenStruct.html).

See [Lago Invoice API](https://docs.getlago.com/api-reference/invoices/update) for valid attributes.

## Issuing a Refund
**Refunding charges requires [Lago Premium!](https://www.getlago.com/pricing)**

If you are self hosting Lago, its fairly trivial to override the premium license check. However, if you are using the cloud service, you will have to purchase Lago Premium. If your organisation has the means, please consider purchasing Lago Premium to support
their open source development. Keep in mind: any changes to the source you make must be released as per the terms of AGPL.

Lago creates refunds by issuing a [Credit Note](https://docs.getlago.com/guide/credit-notes).

The `refund!` method on Pay::Charge will create a credit note automatically for the provided amount. If Lago Premium is not
enabled, this method will raise Pay::Lago::Error.

```ruby
# Refund $10 of a charge, and provide a reason
charge = Pay::Charge.find(1234)
charge.refund!(10_00, reason: "order_cancellation")
```

You can pass a hash of attributes optionally to configure the credit note further.

See [Lago Credit Note API](https://docs.getlago.com/api-reference/credit-notes/create) for valid attributes.