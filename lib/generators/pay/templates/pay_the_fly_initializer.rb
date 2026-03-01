# frozen_string_literal: true

# PayTheFly Configuration for Pay gem
# =====================================
#
# 1. Add required gems to your Gemfile:
#
#   gem "digest-keccak"   # Keccak-256 hashing (required for EIP-712)
#   gem "eth"             # Ethereum key signing (required for payment links)
#
# 2. Set environment variables or Rails credentials:
#
#   PAY_THE_FLY_PROJECT_ID      - Your PayTheFly project ID
#   PAY_THE_FLY_PROJECT_KEY     - HMAC key for webhook signature verification
#   PAY_THE_FLY_PRIVATE_KEY     - Private key for EIP-712 signing (0x-prefixed hex)
#   PAY_THE_FLY_CONTRACT_ADDRESS - PayTheFly smart contract address
#   PAY_THE_FLY_DEFAULT_CHAIN_ID - Default chain (56 for BSC, 728126428 for TRON)
#
# 3. Configure the owner resolver (optional but recommended):
#
#   This callback maps a serial_no from webhook data to the user who placed the order.
#   Without it, only pre-registered wallet addresses will match.

Pay.setup do |config|
  # Uncomment to resolve order owners from webhook serial_no
  # config.pay_the_fly_owner_resolver = ->(serial_no) {
  #   Order.find_by(serial_no: serial_no)&.user
  # }
end
