class User < ApplicationRecord
  pay_customer
  # pay_customer metadata: :stripe_metadata
  # pay_customer metadata: ->(pay_customer) { { user_id: pay_customer.owner_id } }

  def stripe_metadata(pay_customer)
    {
      user_id: id # or pay_customer.owner_id
    }
  end
end
