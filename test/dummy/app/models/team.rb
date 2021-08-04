class Team < ApplicationRecord
  pay_customer

  belongs_to :owner, class_name: "User"

  def email
    owner.email
  end
end
