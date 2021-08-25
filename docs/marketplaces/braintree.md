# Braintree Marketplace Payments

[Braintree Marketplace Overview](https://developers.braintreepayments.com/guides/braintree-marketplace/overview)

**Work In Progress**

Braintree marketplace payments are unfinished and may not work completely.

## Usage

To add Merchant functionality to a model, configure the model:

```ruby
class User
	pay_merchant
end
```

### Assigning a merchant to a customer

Payments for the billable will be processed through the sub-merchant account.

```ruby
@user.set_merchant_processor :braintree, processor_id: "provider_sub_merchant_account"
```

### Creating a marketplace transaction

```ruby
@user.payment_processor.charge(10_00, service_fee_amount: "1.00")
```

Pay will store the `service_fee_amount` for transactions in the `application_fee_amount` field on `Pay::Charge`.
