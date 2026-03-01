# frozen_string_literal: true

module Pay
  module PayTheFly
    class PaymentMethod < Pay::PaymentMethod
      # Sync a wallet address as a payment method
      #
      # @param pay_customer [Pay::PayTheFly::Customer] The customer record
      # @param wallet_address [String] Blockchain wallet address
      # @param chain_symbol [String] Chain identifier (BSC, TRON)
      def self.sync(pay_customer:, wallet_address:, chain_symbol: nil)
        return unless wallet_address.present?

        payment_method = pay_customer.payment_methods.where(processor_id: wallet_address).first_or_initialize

        attrs = {
          processor_id: wallet_address,
          payment_method_type: "crypto_wallet",
          default: true,
          data: {
            brand: chain_symbol || "Crypto",
            last4: wallet_address[-4..],
            wallet_address: wallet_address
          }
        }

        payment_method.update!(attrs)

        # Mark as default
        pay_customer.payment_methods.where.not(id: payment_method.id).update_all(default: false)

        payment_method
      end

      def make_default!
        return if default?

        customer.payment_methods.update_all(default: false)
        update!(default: true)
      end

      def detach
        destroy
      end

      # Display helper
      def wallet_address
        data&.dig("wallet_address") || processor_id
      end

      def short_address
        addr = wallet_address
        return nil unless addr
        "#{addr[0..5]}...#{addr[-4..]}"
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_pay_the_fly_payment_method, Pay::PayTheFly::PaymentMethod
