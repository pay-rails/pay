module Pay
  module Lago
    class PaymentMethod
      attr_reader :pay_payment_method

      delegate :customer, :processor_id, to: :pay_payment_method

      # Lago doesn't provide PaymentMethod IDs, so we have to lookup via the Customer
      def self.sync(pay_customer:)
        payment_method = pay_customer.default_payment_method || pay_customer.build_default_payment_method
        lago_customer = pay_customer.customer
        payment_data = lago_customer.billing_configuration

        payment_method_attr = {
          processor_id: payment_data.provider_customer_id || NanoId.generate,
          type: "card",
          data: Lago.openstruct_to_h(payment_data)
        }

        payment_method.update!(payment_method_attr)
        payment_method
      rescue ::Lago::Api::HttpError => e
        raise Pay::Lago::Error, e
      end

      def initialize(pay_payment_method)
        @pay_payment_method = pay_payment_method
      end

      def make_default!
      end

      def detach
      end
    end
  end
end
