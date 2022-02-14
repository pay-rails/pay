class User < ApplicationRecord
  pay_customer
  # pay_customer metadata: :stripe_metadata
  # pay_customer metadata: ->(user) { { id: user.id } }

  def stripe_metadata
    { id: id }
  end
end
