module Pay
  module AwsMarketplace
    class Subscription < Pay::Subscription
      def api_record(**options)
        self
      end

      def cancel(**options)
        raise UpdateError
      end

      def cancel_now!(**options)
        raise UpdateError
      end

      def paused?
        status == "paused"
      end

      def pause
        raise UpdateError
      end

      def resumable?
        false
      end

      def resume
        raise UpdateError
      end

      def swap(plan, **options)
        raise UpdateError
      end

      def change_quantity(quantity, **options)
        raise UpdateError
      end

      def retry_failed_payment
        raise ChargeError
      end
    end
  end
end
