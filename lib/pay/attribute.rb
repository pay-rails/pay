module Pay
  # Adds Pay methods to ActiveRecord models

  module Attribute
    extend ActiveSupport::Concern

    class_methods do
      def pay_merchant
        has_many :pay_merchants, class_name: "Pay::Merchant", as: :owner, inverse_of: :owner
        has_one :merchant, -> { where(default: true) }, class_name: "Pay::Merchant", as: :owner, inverse_of: :owner

        define_method :set_merchant_processor do |processor|
          ActiveRecord::Base.transaction do
            pay_merchants.update_all(default: false)

            pay_merchant = pay_merchants.where(processor: processor).first_or_initialize
            pay_merchant.update!(processor: processor, default: true)
          end
        end
      end
    end
  end
end
