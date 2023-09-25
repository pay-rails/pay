# Customers

## Adding a Customer to Lago
Calling the `customer` method on an existing Pay::Customer with the Lago processor will automatically create a Lago customer,
with the external_id of the Pay::Customer's processor_id.

If a processor_id is not set, it will use the [GlobalID](https://github.com/rails/globalid) of the Pay::Customer object
as the external_id, and update processor_id to match.

## Adding a Customer from Lago
Creating a Pay::Customer with a matching processor_id to a Lago Customer's external_id, and giving them the Lago processor,
will sync the two records when the `customer` method is called.

## Updating a Lago Customer
Lago Customers can be updated by calling `update_customer!` on the Pay::Customer object. The method takes a Hash of attributes to be
changed, and returns a Lago Customer [OpenStruct](https://ruby-doc.org/current/stdlibs/ostruct/OpenStruct.html).

See [Lago Customer API](https://docs.getlago.com/api-reference/customers/update) for valid attributes.