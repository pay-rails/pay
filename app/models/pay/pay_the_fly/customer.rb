# frozen_string_literal: true

module Pay
  module PayTheFly
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: "Pay::PayTheFly::Charge"
      has_many :subscriptions, dependent: :destroy, class_name: "Pay::PayTheFly::Subscription"
      has_many :payment_methods, dependent: :destroy, class_name: "Pay::PayTheFly::PaymentMethod"
      has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::PayTheFly::PaymentMethod"

      # PayTheFly identifies customers by their wallet address stored as processor_id.
      # There is no external customer API — the wallet address IS the identity.

      def api_record
        # Ensure a processor_id exists (wallet address or generated ID)
        update!(processor_id: NanoId.generate) unless processor_id?
        self
      end

      def update_api_record(**attributes)
        # No external API to sync — PayTheFly is on-chain
        self
      end

      # PayTheFly does not support direct charges — payments are initiated
      # via payment links that the user opens in their wallet.
      #
      # Use `checkout` to generate a payment link instead.
      def charge(amount, options = {})
        raise Pay::Error, "PayTheFly does not support direct charges. Use `checkout` to generate a payment link."
      end

      # PayTheFly is a one-time payment processor — no subscriptions
      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        raise Pay::Error, "PayTheFly does not support subscriptions. Use `checkout` for one-time crypto payments."
      end

      def sync_subscriptions(**options)
        []
      end

      # Generate a PayTheFly payment link
      #
      # @param amount [String, Numeric] Payment amount in human-readable units
      # @param serial_no [String] Unique order identifier (maps to your order/invoice ID)
      # @param chain_id [Integer] Target blockchain (56=BSC, 728126428=TRON)
      # @param token [String] Token contract address (nil = native token)
      # @param deadline [Integer] Unix timestamp deadline
      # @return [String] Payment URL to redirect the user to
      #
      # Example:
      #   customer = user.payment_processor
      #   url = customer.checkout(amount: "0.01", serial_no: "ORDER-123")
      #   redirect_to url
      def checkout(amount:, serial_no:, chain_id: nil, token: nil, deadline: nil, **options)
        api_record unless processor_id?

        Pay::PayTheFly.payment_link(
          amount: amount,
          serial_no: serial_no,
          chain_id: chain_id,
          token: token,
          deadline: deadline
        )
      end

      # Register a wallet address as a payment method
      def add_payment_method(wallet_address = nil, default: true)
        api_record unless processor_id?

        return unless wallet_address.present?

        pay_payment_method = payment_methods.where(processor_id: wallet_address).first_or_initialize
        pay_payment_method.update!(
          processor_id: wallet_address,
          default: default,
          payment_method_type: "crypto_wallet",
          data: {
            brand: "Crypto",
            last4: wallet_address.to_s[-4..],
            wallet_address: wallet_address
          }
        )

        if default
          payment_methods.where.not(id: pay_payment_method.id).update_all(default: false)
          reload_default_payment_method
        end

        pay_payment_method
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_pay_the_fly_customer, Pay::PayTheFly::Customer
