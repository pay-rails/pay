class User < ApplicationRecord
  pay_customer
  # pay_customer metadata: :stripe_metadata
  # pay_customer metadata: ->(user) { { id: user.id } }

  def stripe_metadata
    { user_id: id }
  end
end
