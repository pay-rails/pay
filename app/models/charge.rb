class Charge < ApplicationRecord
  include Pay::Chargeable

  validates :processor_id, uniqueness: { scope: :processor }

  def processor_charge
    case processor
    when "stripe"
      ::Stripe::Charge.retrieve(processor_id)
    when "braintree"
      Pay.braintree_gateway.transactions.find(processor_id)
    end
  end
end
