module Pay
  module FakeProcessor
    class PaymentMethod < Pay::PaymentMethod
      def make_default!
        return if default?

        customer.payment_methods.update_all(default: false)
        update!(default: true)
      end

      def detach
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_fake_processor_payment_method, Pay::FakeProcessor::PaymentMethod
