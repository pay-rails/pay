# Stripe customer reconciliation
Pay tracks customers for each payment processor using the `Pay::Customer` model, but the payment processor logic for customers varies between providers. When using Stripe with Pay, a customer object must exist for a model with `pay_customer` for charges and subscriptions to occur. If a `Pay::Customer` does not exist, one will be created automatically when attempting to operate upon subscriptions and charges.

When creating the new `Pay::Customer`, Pay does not attempt to reconcile the attributes used to create a `Pay::Customer` with existing Stripe customers. As a result, there is a possibility that duplicate Stripe customers may exist with the same attributes (e.g. email) if the application using Pay does not manually reconcile existing Stripe customers with the `Pay::Customer` s.

### Manual reconciliation
The Stripe API can be used to list all existing Stripe customers. This allows the application to implement the necessary logic for creating and associating `Pay::Customer` s within the application.

There are two methods available to associate existing Stripe customers with a `pay_customer` model.

* `Model.set_payment_processor`: Finds or creates a `Pay::Customer` and marks it as the default for the model (the default `Pay::Customer` is the `Model.payment_processor`). It also removes the default flag from other `Pay::Customer`s and `Pay::PaymentMethod`s. Example: `User.set_payment_processor("stripe", processor_id: "cus_O1PngYajzbTEST")`
* `Model.add_payment_processor`: Finds or creates a `Pay::Customer`, updating the `Pay::Customer` with the attributes provided. This method does not mutate default flags for existing `Pay::Customer`s that exist. Example: `User.add_payment_processor("stripe", processor_id: "cus_O1PngYajzbTEST")`. 

### Automated reconciliation
Automated reconciliation is possible through the use of ActiveRecord callbacks.

*Note*: Care should be taken with automated reconciliation, as automated reconciliation may have security and privacy implications on your application. Automatically associating a Pay customer to a `pay_customer` model based on unverified attributes could be used to abuse the existing payment methods. An example of such a situation would be automatically associating a Pay customer based on an email address of a user, where the user is not required to verify the email prior to authentication.

#### One-to-one reconciliation
To automatically reconcile an existing Stripe customer with a `pay_customer` model, the following example can be modified to search for an existing Stripe customer by email address, and if one exists, it will be added as the default payment processor. If more than one Stripe customer exists with the same email address, none of the existing customers will be associated, and a new Stripe customer will be created by Pay when necessary.

```ruby
class User < ActiveRecord
  after_create :reconcile_stripe_customer

  def reconcile_stripe_customer
    # Find all customers with the same email address
    stripe_customers = ::Stripe::Customer.list(email: self.email)["data"]

    # If there is more than one existing customer or no existing customer,
    # do nothing, otherwise add the customer as the default payment processor
    return if stripe_customers.length != 1

    self.set_payment_processor("stripe", processor_id: stripe_customers[0]["id"])
  end
end
```

#### One-to-many reconciliation
To automatically reconcile multiple existing Stripe customers with a `pay_customer` model after a new record is created, the following example can be modified to search for existing Stripe customers by email address, and if any exist, they will be added as a `Pay::Customer`. The last customer created will be the default payment processor if none previously existed.

```ruby
class User < ActiveRecord
  after_create :reconcile_stripe_customers

  def reconcile_stripe_customers
    # Find all customers with the same email address
    Stripe::Customer.list(email: self.email).auto_paging_each do |customer|
      # Create the pay customer, associating it to the current user
      Pay::Customer.create(owner: self, processor: "stripe", processor_id: customer["id"])
    end
  end
end
```

### Backfilling subscriptions and charges for reconciled customers
When `Pay::Customer`s are created using `Model.set_payment_processor` or `Model.add_payment_processor`, existing Stripe subscriptions and charges are not automatically backfilled.

To backfill active subscriptions and the charges associated with those subscriptions, the `Pay::Stripe::Billable.new(pay_customer).sync_subscriptions` method can be used. To backfill all subscriptions including canceled subscriptions, the `status: "all"` parameter can be provided (e.g. `Pay::Stripe::Billable.new(pay_customer).sync_subscriptions(status: "all")`).

An equivalent method to backfilling charges not associated with subscriptions is not currently implemented within Pay, however `Pay::Charge`s can be created manually by the application such as in the example below.

```ruby
Stripe::Charge.list.auto_paging_each { |charge| Pay::Stripe::Charge.sync(charge.id) }
```