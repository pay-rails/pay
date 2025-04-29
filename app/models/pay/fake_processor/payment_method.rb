module Pay
  module FakeProcessor
    class PaymentMethod < Pay::PaymentMethod
      def make_default!
      end

      def detach
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_fake_processor_payment_method, Pay::FakeProcessor::PaymentMethod
