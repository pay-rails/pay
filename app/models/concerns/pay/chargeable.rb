module Pay
  module Chargeable
    extend ActiveSupport::Concern

    included do
      # Associations
      belongs_to :owner, class_name: Pay.billable_class, foreign_key: :owner_id

      # Validations
      validates :amount, presence: true
      validates :processor, presence: true
      validates :processor_id, presence: true
      validates :card_type, presence: true

      self.table_name = Pay.chargeable_table
    end

    def processor_charge
      send("#{processor}_charge")
    end

    def refund!(amount = nil)
      send("#{processor}_refund!", amount)
    end

    def stripe_charge
      Stripe::Charge.retrieve(processor_id)
    end

    def stripe_refund!(amount)
      Stripe::Refund.create(
        charge: processor_id,
        amount: amount
      )

      update(amount_refunded: amount)
    end

  end
end
