module Pay
  class Charge < ApplicationRecord
    self.table_name = Pay.chargeable_table

    # Only serialize for non-json columns
    serialize :data, coder: JSON unless json_column?("data")

    # Associations
    belongs_to :owner, polymorphic: true

    # Scopes
    scope :sorted, -> { order(created_at: :desc) }
    default_scope -> { sorted }

    # Validations
    validates :amount, presence: true
    validates :processor, presence: true
    validates :processor_id, presence: true
    validates :card_type, presence: true

    def processor_charge
      send("#{processor}_charge")
    end

    def refund!(refund_amount = nil)
      refund_amount ||= amount
      send("#{processor}_refund!", refund_amount)
    end

    def charged_to
      "#{card_type} (**** **** **** #{card_last4})"
    end

    def stripe?
      processor == "stripe"
    end

    def braintree?
      processor == "braintree"
    end

    def paypal?
      braintree? && card_type == "PayPal"
    end

    def paddle?
      processor == "paddle"
    end
  end
end
