# frozen_string_literal: true

module Pay
  module PayTheFly
    class Charge < Pay::Charge
      # Sync a payment webhook event into a Pay::Charge record.
      #
      # Webhook data fields:
      #   project_id, chain_symbol, tx_hash, wallet, value, fee,
      #   serial_no, tx_type (1=payment, 2=withdrawal), confirmed, create_at
      def self.sync_from_webhook(data)
        data = data.with_indifferent_access

        tx_hash = data["tx_hash"]
        return if tx_hash.blank?

        # Find customer by wallet address (processor_id)
        wallet = data["wallet"]
        pay_customer = Pay::PayTheFly::Customer.find_by(processor_id: wallet)

        # Auto-create customer if we can find an owner via serial_no callback
        unless pay_customer
          owner = resolve_owner_from_serial_no(data["serial_no"])
          if owner
            pay_customer = owner.set_payment_processor(:pay_the_fly)
            pay_customer.update!(processor_id: wallet)
          else
            Rails.logger.warn "[Pay] PayTheFly webhook: no customer found for wallet #{wallet}"
            return
          end
        end

        # Register wallet as payment method
        pay_customer.add_payment_method(wallet, default: true)

        # Determine chain details for amount conversion
        chain = Pay::PayTheFly.chain_for(data["chain_symbol"])
        decimals = chain ? chain[:decimals] : 18

        # Convert on-chain value to cents (integer)
        # PayTheFly returns value as string in smallest unit
        raw_value = BigDecimal(data["value"].to_s)
        fee_value = BigDecimal(data.fetch("fee", "0").to_s)

        # Store amount in the smallest unit the chain uses
        # For database consistency, we store as integer cents
        # The currency field indicates the chain token
        attributes = {
          processor_id: tx_hash,
          amount: raw_value.to_i,
          amount_refunded: 0,
          currency: data["chain_symbol"]&.downcase || "bsc",
          created_at: data["create_at"] ? Time.at(data["create_at"].to_i) : Time.current,
          data: {
            payment_method_type: "crypto_wallet",
            brand: data["chain_symbol"] || "Crypto",
            last4: wallet.to_s[-4..],
            tx_hash: tx_hash,
            chain_symbol: data["chain_symbol"],
            serial_no: data["serial_no"],
            fee: fee_value.to_i,
            wallet: wallet,
            confirmed: data["confirmed"]
          }
        }

        # Update or create
        if (pay_charge = pay_customer.charges.find_by(processor_id: tx_hash))
          pay_charge.with_lock { pay_charge.update!(attributes) }
          pay_charge
        else
          pay_customer.charges.create!(attributes)
        end
      end

      # Sync a withdrawal webhook event (tx_type: 2)
      # Withdrawals are stored as negative charges for audit trail
      def self.sync_withdrawal_from_webhook(data)
        data = data.with_indifferent_access

        tx_hash = data["tx_hash"]
        return if tx_hash.blank?

        wallet = data["wallet"]
        pay_customer = Pay::PayTheFly::Customer.find_by(processor_id: wallet)
        return unless pay_customer

        raw_value = BigDecimal(data["value"].to_s)
        fee_value = BigDecimal(data.fetch("fee", "0").to_s)

        attributes = {
          processor_id: "withdrawal:#{tx_hash}",
          amount: raw_value.to_i,
          amount_refunded: raw_value.to_i, # Mark as fully "refunded" since it's a withdrawal
          currency: data["chain_symbol"]&.downcase || "bsc",
          created_at: data["create_at"] ? Time.at(data["create_at"].to_i) : Time.current,
          data: {
            payment_method_type: "crypto_wallet",
            brand: data["chain_symbol"] || "Crypto",
            last4: wallet.to_s[-4..],
            tx_hash: tx_hash,
            chain_symbol: data["chain_symbol"],
            serial_no: data["serial_no"],
            fee: fee_value.to_i,
            wallet: wallet,
            confirmed: data["confirmed"],
            withdrawal: true
          }
        }

        if (pay_charge = pay_customer.charges.find_by(processor_id: "withdrawal:#{tx_hash}"))
          pay_charge.with_lock { pay_charge.update!(attributes) }
          pay_charge
        else
          pay_customer.charges.create!(attributes)
        end
      end

      # Override charged_to to display crypto wallet info
      def charged_to
        wallet = data&.dig("wallet")
        chain = data&.dig("chain_symbol") || "Crypto"
        if wallet.present?
          "#{chain} (#{wallet[0..5]}...#{wallet[-4..]})"
        else
          "Crypto Wallet"
        end
      end

      # Transaction explorer URL
      def explorer_url
        chain_symbol = data&.dig("chain_symbol")
        tx = data&.dig("tx_hash")
        return nil unless tx

        case chain_symbol&.upcase
        when "BSC"
          "https://bscscan.com/tx/#{tx}"
        when "TRON"
          "https://tronscan.org/#/transaction/#{tx}"
        end
      end

      def withdrawal?
        data&.dig("withdrawal") == true
      end

      private

      # Hook for applications to resolve an owner from a serial_no.
      # Override this in your app's initializer:
      #
      #   Pay::PayTheFly::Charge.define_method(:resolve_owner_from_serial_no) do |serial_no|
      #     Order.find_by(serial_no: serial_no)&.user
      #   end
      #
      # Or configure via Pay.setup:
      #   Pay.pay_the_fly_owner_resolver = ->(serial_no) { ... }
      def self.resolve_owner_from_serial_no(serial_no)
        if Pay.respond_to?(:pay_the_fly_owner_resolver) && Pay.pay_the_fly_owner_resolver
          Pay.pay_the_fly_owner_resolver.call(serial_no)
        else
          nil
        end
      end
    end
  end
end

ActiveSupport.run_load_hooks :pay_pay_the_fly_charge, Pay::PayTheFly::Charge
