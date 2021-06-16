# Braintree Marketplace Payments

[Braintree Marketplace Overview](https://developers.braintreepayments.com/guides/braintree-marketplace/overview)

## Usage

To add Merchant functionality to a model, run the generator:

```bash
rails g pay:merchant User
rails db:migrate
```

### Assigning a merchant to a customer

Payments for the billable will be processed through the sub-merchant account.

```ruby
@billable.update(braintree_account: "provider_sub_merchant_account")
```

### Creating a marketplace transaction

```ruby
@billable.braintree_account = "provider_sub_merchant_account"
@billable.charge(10_00, service_fee_amount: "1.00")
```

Pay will store the `service_fee_amount` for transactions in the `application_fee_amount` field on `Pay::Charge`.
