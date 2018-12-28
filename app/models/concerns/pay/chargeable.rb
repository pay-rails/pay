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

    if defined?(Receipts::Receipt) && required_receipt_attributes?
      def receipt
        Receipts::Receipt.new(
          id: id,
          product: Pay.config.application_name,
          company: {
            name: Pay.config.business_name,
            address: Pay.config.business_address,
            email: Pay.config.support_email,
          },
          line_items: line_items,
        )
      end

      def line_items
        line_items = [
          ["Date",           created_at.to_s],
          ["Account Billed", "#{owner.name} (#{owner.email})"],
          ["Product",        Pay.config.application_name],
          ["Amount",         ActionController::Base.helpers.number_to_currency(amount / 100.0)],
          ["Charged to",     charged_to],
        ]
        line_items << ["Additional Info", owner.extra_billing_info] if owner.extra_billing_info?
        line_items
      end
    end

    def charged_to
      "#{card_type} (**** **** **** #{card_last4})"
    end

    private

    def required_receipt_attributes?
      Pay.config.application_name.present? &&
      Pay.config.business_name &&
      Pay.config.business_address &&
      Pay.config.support_email
    end
  end
end
