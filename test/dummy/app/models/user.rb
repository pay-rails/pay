class User < ApplicationRecord
  pay_customer
  # pay_customer stripe_attributes: :stripe_attributes
  # pay_customer stripe_attributes: ->(pay_customer) { { metadata: { user_id: pay_customer.owner_id } } }

  def stripe_attributes(pay_customer)
    {
      description: "description",
      metadata: {
        user_id: id # or pay_customer.owner_id
      }
    }
  end

  def braintree_attributes(pay_customer)
    { company: "Company" }
  end
end
