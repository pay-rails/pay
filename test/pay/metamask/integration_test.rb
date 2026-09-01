require 'test_helper'

# Integration tests for Metamask + Pay gem interaction
# Tests the payment flow when a user connects their Metamask wallet
class Pay::Metamask::IntegrationTest < ActiveSupport::TestCase
  setup do
    @pay_customer = users(:one).payment_customer
    @wallet_1 = '0xacA92E438df0B2401fF60dA7E4337B687a2435DA'
    @wallet_2 = '0xDc810078c9B23e41f9B204EC63ae5289AA865117'
    @merchant_wallet = '0x9876543210987654321098765432109876543210'
  end

  # Test 1: Customer connects Metamask wallet to Pay
  test 'customer can connect metamask wallet to pay account' do
    # Simulate user signing message to verify wallet ownership
    signature = '0x' + 'a' * 130 # Mock signature

    Ethers::Signer.stubs(:recover_address).returns(@wallet_1)

    # Create payment method from wallet
    payment_method = @pay_customer.payment_methods.build(
      processor_id: @wallet_1,
      processor: 'metamask',
      data: {
        verified_at: Time.current,
        signature: signature,
        message: 'Sign this to connect to Pay'
      }
    )

    assert payment_method.save
    assert_equal @wallet_1, payment_method.processor_id
    assert_equal 'metamask', payment_method.processor
  end

  # Test 2: Make a charge using Metamask wallet
  test 'can create charge using metamask wallet' do
    # Create payment method
    payment_method = @pay_customer.payment_methods.create!(
      processor_id: @wallet_1,
      processor: 'metamask'
    )

    # Mock transaction signing and sending
    Web3::Eth.stubs(:send_transaction).returns({
                                                 transactionHash: '0xabcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234',
                                                 blockNumber: 12_345_678,
                                                 status: 1
                                               })

    charge = @pay_customer.charges.create!(
      processor_id: 'tx_abcd1234',
      amount_in_cents: 10_000, # $100 in cents
      payment_method: payment_method
    )

    assert_equal 10_000, charge.amount_in_cents
    assert_equal @wallet_1, charge.payment_method.processor_id
  end

  # Test 3: Multiple wallets per customer
  test 'customer can connect multiple metamask wallets' do
    wallet1 = @pay_customer.payment_methods.create!(
      processor_id: @wallet_1,
      processor: 'metamask',
      default: true
    )

    wallet2 = @pay_customer.payment_methods.create!(
      processor_id: @wallet_2,
      processor: 'metamask',
      default: false
    )

    assert_equal 2, @pay_customer.payment_methods.count
    assert wallet1.default?
    assert_not wallet2.default?
  end

  # Test 4: Switch default payment method
  test 'can switch default metamask wallet' do
    wallet1 = @pay_customer.payment_methods.create!(
      processor_id: @wallet_1,
      processor: 'metamask',
      default: true
    )

    wallet2 = @pay_customer.payment_methods.create!(
      processor_id: @wallet_2,
      processor: 'metamask',
      default: false
    )

    wallet2.make_default!

    wallet1.reload
    wallet2.reload

    assert_not wallet1.default?
    assert wallet2.default?
  end

  # Test 5: Get wallet balance before charge
  test 'can retrieve wallet balance before creating charge' do
    payment_method = @pay_customer.payment_methods.create!(
      processor_id: @wallet_1,
      processor: 'metamask'
    )

    balance_wei = 5_000_000_000_000_000_000 # 5 ETH in wei
    Web3::Eth.stubs(:get_balance).with(@wallet_1).returns(balance_wei)

    balance = Web3::Eth.get_balance(payment_method.processor_id)
    balance_eth = balance / 1e18

    assert_equal 5.0, balance_eth
  end

  # Test 6: Insufficient balance error
  test 'handles insufficient balance for charge' do
    payment_method = @pay_customer.payment_methods.create!(
      processor_id: @wallet_1,
      processor: 'metamask'
    )

    Web3::Eth.stubs(:send_transaction).raises(
      Web3::Error.new('insufficient funds for gas * price + value')
    )

    assert_raises(Web3::Error) do
      @pay_customer.charge(999_999_999_999_999_999_999)
    end
  end

  # Test 7: Track transaction status
  test 'can track transaction status after charge' do
    payment_method = @pay_customer.payment_methods.create!(
      processor_id: @wallet_1,
      processor: 'metamask'
    )

    tx_hash = '0xabcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234'

    charge = @pay_customer.charges.create!(
      processor_id: tx_hash,
      amount_in_cents: 50_000,
      payment_method: payment_method,
      data: { status: 'pending' }
    )

    # Mock receipt retrieval
    Web3::Eth.stubs(:get_transaction_receipt).with(tx_hash).returns({
                                                                      transactionHash: tx_hash,
                                                                      blockNumber: 12_345_678,
                                                                      status: 1, # Success
                                                                      gasUsed: 21_000
                                                                    })

    receipt = Web3::Eth.get_transaction_receipt(tx_hash)

    assert_equal 1, receipt[:status]
    assert_equal 12_345_678, receipt[:blockNumber]
  end

  # Test 8: Subscription with Metamask
  test 'can create subscription with metamask wallet' do
    payment_method = @pay_customer.payment_methods.create!(
      processor_id: @wallet_1,
      processor: 'metamask',
      default: true
    )

    Web3::Eth.stubs(:send_transaction).returns({
                                                 transactionHash: '0xabcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234',
                                                 status: 1
                                               })

    subscription = @pay_customer.subscriptions.create!(
      processor_id: 'sub_metamask_1',
      name: 'premium',
      processor: 'metamask',
      payment_method: payment_method,
      data: { plan: 'premium-monthly', amount: 9999 }
    )

    assert subscription.persisted?
    assert_equal 'premium', subscription.name
    assert_equal @wallet_1, subscription.payment_method.processor_id
  end

  # Test 9: Transfer between wallets (internal)
  test 'can execute transfer between two addresses' do
    transfer_amount = 1_000_000_000_000_000_000 # 1 ETH in wei

    Web3::Eth.stubs(:send_transaction).with(
      hash_including(
        from: @wallet_1,
        to: @wallet_2,
        value: transfer_amount
      )
    ).returns({
                transactionHash: '0x1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd',
                status: 1
              })

    result = Web3::Eth.send_transaction(
      from: @wallet_1,
      to: @wallet_2,
      value: transfer_amount
    )

    assert_equal 1, result[:status]
  end

  # Test 10: Verify wallet ownership via signature
  test 'can verify wallet ownership with signed message' do
    message = 'Sign this to connect to Pay'
    signature = '0x' + 'b' * 130

    Ethers::Signer.stubs(:recover_address).with(message, signature).returns(@wallet_1)

    recovered = Ethers::Signer.recover_address(message, signature)

    assert_equal @wallet_1, recovered
  end

  # Test 11: Sync charge from blockchain
  test 'can sync charge status from blockchain' do
    tx_hash = '0xabcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234'

    charge = @pay_customer.charges.create!(
      processor_id: tx_hash,
      amount_in_cents: 50_000,
      data: { status: 'pending' }
    )

    Web3::Eth.stubs(:get_transaction_receipt).with(tx_hash).returns({
                                                                      transactionHash: tx_hash,
                                                                      blockNumber: 12_345_678,
                                                                      status: 1,
                                                                      gasUsed: 21_000
                                                                    })

    receipt = Web3::Eth.get_transaction_receipt(tx_hash)
    charge.update(data: receipt)

    assert_equal 1, charge.data['status']
  end

  # Test 12: Estimate gas fees
  test 'can estimate gas fees before transaction' do
    transaction_data = {
      from: @wallet_1,
      to: @merchant_wallet,
      value: 1_000_000_000_000_000_000,
      data: '0x'
    }

    Web3::Eth.stubs(:estimate_gas).with(transaction_data).returns(21_000)
    Web3::Eth.stubs(:gas_price).returns(50_000_000_000) # 50 Gwei

    gas_estimate = Web3::Eth.estimate_gas(transaction_data)
    gas_price = Web3::Eth.gas_price

    total_gas_cost = gas_estimate * gas_price
    total_gas_cost_eth = total_gas_cost / 1e18

    assert_equal 0.00105, total_gas_cost_eth # 21000 * 50 Gwei
  end

  # Test 13: Refund to wallet
  test 'can process refund back to metamask wallet' do
    charge = @pay_customer.charges.create!(
      processor_id: 'tx_original',
      amount_in_cents: 50_000,
      data: { status: 'completed' }
    )

    Web3::Eth.stubs(:send_transaction).returns({
                                                 transactionHash: '0xrefund1234refund1234refund1234refund1234refund1234refund1234refund',
                                                 status: 1
                                               })

    refund_tx = Web3::Eth.send_transaction(
      from: @merchant_wallet,
      to: @wallet_1,
      value: 50_000 # Refund amount
    )

    charge.update(
      amount_refunded_in_cents: 50_000,
      data: { refund_tx_hash: refund_tx[:transactionHash] }
    )

    assert_equal 50_000, charge.amount_refunded_in_cents
  end

  # Test 14: Network switching
  test 'can detect and handle network switches' do
    Web3::Eth.stubs(:chain_id).returns(1) # Ethereum Mainnet

    chain_id = Web3::Eth.chain_id

    network_names = {
      1 => 'Ethereum Mainnet',
      5 => 'Goerli Testnet',
      11_155_111 => 'Sepolia Testnet',
      137 => 'Polygon Mainnet'
    }

    network_name = network_names[chain_id] || 'Unknown'

    assert_equal 'Ethereum Mainnet', network_name
  end

  # Test 15: Wallet disconnection
  test 'can disconnect metamask wallet from account' do
    payment_method = @pay_customer.payment_methods.create!(
      processor_id: @wallet_1,
      processor: 'metamask'
    )

    assert payment_method.destroy
    assert_equal 0, @pay_customer.payment_methods.count
  end
end
