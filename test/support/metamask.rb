require 'test_helper'

# Helper methods and fixtures for Metamask testing
module Pay::MetamaskTestHelpers
  # Mock wallet data
  WALLET_1 = '0xacA92E438df0B2401fF60dA7E4337B687a2435DA'
  WALLET_2 = '0xDc810078c9B23e41f9B204EC63ae5289AA865117'
  MERCHANT_WALLET = '0x9876543210987654321098765432109876543210'

  # Create a fake Metamask payment method
  def create_metamask_payment_method(customer, wallet_address = WALLET_1, default: true)
    customer.payment_methods.create!(
      processor_id: wallet_address,
      processor: 'metamask',
      default: default,
      data: {
        verified_at: Time.current,
        signature: '0x' + 'a' * 130,
        message: 'Sign this to connect to Pay'
      }
    )
  end

  # Create a fake transaction result
  def fake_transaction_result(tx_hash = nil, status: 1, block_number: 12_345_678)
    {
      transactionHash: tx_hash || ('0x' + SecureRandom.hex(32)),
      blockNumber: block_number,
      status: status,
      gasUsed: 21_000,
      confirmations: 12
    }
  end

  # Create fake wallet balance
  def fake_wallet_balance(amount_eth = 5.0)
    (amount_eth * 1e18).to_i
  end

  # Create fake signed message
  def fake_signed_message(message = 'Sign this to connect to Pay', wallet = WALLET_1)
    {
      message: message,
      signature: '0x' + 'b' * 130,
      address: wallet
    }
  end

  # Create fake transaction object
  def fake_metamask_transaction(
    from: WALLET_1,
    to: MERCHANT_WALLET,
    value: 1_000_000_000_000_000_000,
    data: '0x',
    gas: 21_000,
    gas_price: 50_000_000_000
  )
    {
      from: from,
      to: to,
      value: value,
      data: data,
      gas: gas,
      gasPrice: gas_price,
      nonce: 42
    }
  end

  # Create fake transaction receipt
  def fake_transaction_receipt(
    tx_hash = nil,
    status: 1,
    block_number: 12_345_678,
    from: WALLET_1,
    to: MERCHANT_WALLET
  )
    {
      transactionHash: tx_hash || ('0x' + SecureRandom.hex(32)),
      blockNumber: block_number,
      blockHash: '0x' + SecureRandom.hex(32),
      status: status,
      from: from,
      to: to,
      gasUsed: 21_000,
      cumulativeGasUsed: 1_000_000,
      contractAddress: nil,
      logs: [],
      logsBloom: '0x' + '0' * 512
    }
  end

  # Stub Metamask gas estimation
  def stub_gas_estimate(gas_amount = 21_000)
    Web3::Eth.stubs(:estimate_gas).returns(gas_amount)
  end

  # Stub Metamask gas price
  def stub_gas_price(price_wei = 50_000_000_000) # 50 Gwei
    Web3::Eth.stubs(:gas_price).returns(price_wei)
  end

  # Stub wallet balance check
  def stub_wallet_balance(wallet, balance_eth = 5.0)
    Web3::Eth.stubs(:get_balance).with(wallet).returns(fake_wallet_balance(balance_eth))
  end

  # Stub transaction sending
  def stub_send_transaction(result = nil)
    result ||= fake_transaction_result
    Web3::Eth.stubs(:send_transaction).returns(result)
  end

  # Stub transaction receipt retrieval
  def stub_transaction_receipt(tx_hash, status: 1)
    Web3::Eth.stubs(:get_transaction_receipt).with(tx_hash).returns(
      fake_transaction_receipt(tx_hash, status: status)
    )
  end

  # Stub message signing
  def stub_sign_message(wallet = WALLET_1)
    Ethers::Signer.stubs(:sign_message).returns(
      fake_signed_message(wallet: wallet)[:signature]
    )
  end

  # Stub message recovery
  def stub_recover_address(message, signature, wallet = WALLET_1)
    Ethers::Signer.stubs(:recover_address).with(message, signature).returns(wallet)
  end

  # Stub chain ID (network detection)
  def stub_chain_id(chain_id = 1) # 1 = Mainnet
    Web3::Eth.stubs(:chain_id).returns(chain_id)
  end

  # Stub nonce retrieval
  def stub_nonce(wallet, nonce_value = 42)
    Web3::Eth.stubs(:get_transaction_count).with(wallet).returns(nonce_value)
  end

  # Load JSON fixture for webhook events
  def json_fixture(name)
    path = File.join(Rails.root, 'test', 'fixtures', 'files', 'metamask', "#{name}.json")
    JSON.parse(File.read(path))
  end
end

# Include helpers in all test classes
class ActiveSupport::TestCase
  include Pay::MetamaskTestHelpers
end
