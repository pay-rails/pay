# frozen_string_literal: true

module Pay
  module PayTheFly
    class Error < Pay::Error
    end

    module Webhooks
      autoload :PaymentConfirmed, "pay/pay_the_fly/webhooks/payment_confirmed"
      autoload :WithdrawalConfirmed, "pay/pay_the_fly/webhooks/withdrawal_confirmed"
    end

    extend Env

    # Supported chains with their metadata
    CHAINS = {
      56 => {symbol: "BSC", name: "BNB Smart Chain", decimals: 18, native_token: "0x0000000000000000000000000000000000000000"},
      728126428 => {symbol: "TRON", name: "TRON", decimals: 6, native_token: "T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb"}
    }.freeze

    # EIP-712 domain constants
    EIP712_DOMAIN_NAME = "PayTheFlyPro"
    EIP712_DOMAIN_VERSION = "1"

    # Payment link base URL
    PAYMENT_BASE_URL = "https://pro.paythefly.com/pay"

    def self.enabled?
      return false unless Pay.enabled_processors.include?(:pay_the_fly)

      # Requires digest-keccak gem (Keccak-256 ≠ SHA3-256!)
      unless defined?(::Digest::Keccak)
        raise "[Pay] digest-keccak gem is required for PayTheFly. Add `gem 'digest-keccak'` to your Gemfile."
      end

      true
    end

    def self.setup
      # No external SDK to configure — PayTheFly uses direct webhook + payment links
    end

    # ─── Configuration Accessors ───────────────────────────────────────

    def self.project_id
      find_value_by_name(:pay_the_fly, :project_id)
    end

    def self.project_key
      find_value_by_name(:pay_the_fly, :project_key)
    end

    def self.signing_secret
      find_value_by_name(:pay_the_fly, :signing_secret)
    end

    def self.private_key
      find_value_by_name(:pay_the_fly, :private_key)
    end

    def self.default_chain_id
      value = find_value_by_name(:pay_the_fly, :default_chain_id)
      value ? value.to_i : 56
    end

    def self.contract_address
      find_value_by_name(:pay_the_fly, :contract_address)
    end

    # ─── Webhook Registration ──────────────────────────────────────────

    def self.configure_webhooks
      Pay::Webhooks.configure do |events|
        events.subscribe "pay_the_fly.payment_confirmed", Pay::PayTheFly::Webhooks::PaymentConfirmed.new
        events.subscribe "pay_the_fly.withdrawal_confirmed", Pay::PayTheFly::Webhooks::WithdrawalConfirmed.new
      end
    end

    # ─── Keccak-256 Hashing ────────────────────────────────────────────
    #
    # CRITICAL: Keccak-256 ≠ SHA3-256!
    # The NIST SHA-3 standard added padding that differs from original Keccak.
    # Ethereum/EIP-712 uses the original Keccak-256.
    # Ruby: use `Digest::Keccak.new(256)` from digest-keccak gem.
    # NEVER use `OpenSSL::Digest.new('SHA3-256')` — it produces different output.

    def self.keccak256(data)
      Digest::Keccak.new(256).digest(data.b)
    end

    # ─── EIP-712 Signature Generation ──────────────────────────────────

    # Compute EIP-712 domain separator
    def self.domain_separator(chain_id:, verifying_contract:)
      type_hash = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
      )

      keccak256(
        abi_encode(
          [:bytes32, :bytes32, :bytes32, :uint256, :address],
          [type_hash, keccak256(EIP712_DOMAIN_NAME), keccak256(EIP712_DOMAIN_VERSION), chain_id, verifying_contract]
        )
      )
    end

    # Compute struct hash for PaymentRequest
    def self.payment_struct_hash(project_id:, token:, amount:, serial_no:, deadline:)
      type_hash = keccak256(
        "PaymentRequest(string projectId,address token,uint256 amount,string serialNo,uint256 deadline)"
      )

      keccak256(
        abi_encode(
          [:bytes32, :bytes32, :address, :uint256, :bytes32, :uint256],
          [type_hash, keccak256(project_id), token, amount, keccak256(serial_no), deadline]
        )
      )
    end

    # Compute struct hash for WithdrawalRequest
    def self.withdrawal_struct_hash(user:, project_id:, token:, amount:, serial_no:, deadline:)
      type_hash = keccak256(
        "WithdrawalRequest(address user,string projectId,address token,uint256 amount,string serialNo,uint256 deadline)"
      )

      keccak256(
        abi_encode(
          [:bytes32, :address, :bytes32, :address, :uint256, :bytes32, :uint256],
          [type_hash, user, keccak256(project_id), token, amount, keccak256(serial_no), deadline]
        )
      )
    end

    # Sign a typed data hash with EIP-712
    # Returns "0x"-prefixed hex signature
    def self.sign_typed_data(chain_id:, verifying_contract:, struct_hash:)
      domain = domain_separator(chain_id: chain_id, verifying_contract: verifying_contract)

      # EIP-712: "\x19\x01" ‖ domainSeparator ‖ hashStruct(message)
      digest = keccak256("\x19\x01".b + domain + struct_hash)

      key = ::Eth::Key.new(priv: private_key)
      signature = key.sign(digest)
      signature.start_with?("0x") ? signature : "0x#{signature}"
    end

    # ─── Payment Link Generation ───────────────────────────────────────

    # Generate a payment link URL
    #
    # @param amount [String, BigDecimal, Numeric] Amount in human-readable units (e.g., "0.01" BNB)
    # @param serial_no [String] Unique order/serial number
    # @param chain_id [Integer] Blockchain chain ID (default: configured default)
    # @param token [String] Token contract address (default: native token for chain)
    # @param deadline [Integer] Unix timestamp deadline (default: 30 minutes from now)
    # @return [String] Full payment URL
    def self.payment_link(amount:, serial_no:, chain_id: nil, token: nil, deadline: nil)
      chain_id ||= default_chain_id
      chain_config = CHAINS.fetch(chain_id) { raise Error, "Unsupported chain_id: #{chain_id}" }
      token ||= chain_config[:native_token]
      deadline ||= (Time.current + 30.minutes).to_i

      # Convert human amount to on-chain integer (wei/sun)
      amount_wei = to_wei(amount, chain_config[:decimals])

      struct_hash = payment_struct_hash(
        project_id: project_id,
        token: token,
        amount: amount_wei,
        serial_no: serial_no,
        deadline: deadline
      )

      signature = sign_typed_data(
        chain_id: chain_id,
        verifying_contract: contract_address,
        struct_hash: struct_hash
      )

      params = {
        chainId: chain_id,
        projectId: project_id,
        amount: amount.to_s,
        serialNo: serial_no,
        deadline: deadline,
        signature: signature,
        token: token
      }

      "#{PAYMENT_BASE_URL}?#{URI.encode_www_form(params)}"
    end

    # ─── Webhook Signature Verification ────────────────────────────────

    # Verify HMAC-SHA256 webhook signature
    # Sign = HMAC-SHA256(data + "." + timestamp, projectKey)
    def self.verify_webhook_signature(data:, timestamp:, signature:)
      payload = "#{data}.#{timestamp}"
      expected = OpenSSL::HMAC.hexdigest("SHA256", project_key, payload)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end

    # ─── Unit Conversion Helpers ───────────────────────────────────────

    # Convert a human-readable amount to smallest unit (wei for BSC, sun for TRON)
    def self.to_wei(amount, decimals)
      (BigDecimal(amount.to_s) * BigDecimal(10**decimals)).to_i
    end

    # Convert from smallest unit back to human-readable
    def self.from_wei(amount, decimals)
      BigDecimal(amount.to_s) / BigDecimal(10**decimals)
    end

    # Chain metadata lookup
    def self.chain_for(chain_id_or_symbol)
      if chain_id_or_symbol.is_a?(Integer)
        CHAINS[chain_id_or_symbol]
      else
        CHAINS.values.find { |c| c[:symbol] == chain_id_or_symbol.to_s.upcase }
      end
    end

    # ─── ABI Encoding ──────────────────────────────────────────────────

    # Standard ABI-encode values as 32-byte words (for EIP-712 struct hashing)
    # Each value occupies exactly 32 bytes, matching Solidity's abi.encode().
    def self.abi_encode(types, values)
      result = "".b

      types.each_with_index do |type, i|
        value = values[i]

        case type
        when :bytes32
          # Already a 32-byte binary string
          if value.is_a?(String) && value.encoding == Encoding::ASCII_8BIT && value.bytesize == 32
            result << value
          else
            raise Error, "Expected 32-byte binary string for bytes32, got #{value.class} (#{value.bytesize} bytes)"
          end

        when :address
          # Normalize: strip 0x prefix, decode hex, left-pad to 32 bytes
          addr_hex = value.to_s.sub(/\A0x/i, "").rjust(40, "0")
          result << ("\x00" * 12).b + [addr_hex].pack("H40")

        when :uint256
          # Encode as big-endian 256-bit (32-byte) integer
          hex = value.to_i.to_s(16).rjust(64, "0")
          result << [hex].pack("H64")
        end
      end

      result
    end
  end
end
