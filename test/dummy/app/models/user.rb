class User < ApplicationRecord
  pay_customer
  # pay_customer fields: :stripe_fields
  # pay_customer fields: ->(pay_customer) { { metadata: { user_id: pay_customer.owner_id } } }

  def stripe_fields(pay_customer)
    {
      metadata: {
        user_id: id # or pay_customer.owner_id
      }
    }
  end
end
