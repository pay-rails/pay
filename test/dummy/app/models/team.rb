class Team < ApplicationRecord
  pay_customer
  pay_merchant

  belongs_to :owner, polymorphic: true

  def email
    owner.email
  end
end
