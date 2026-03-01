# frozen_string_literal: true

require "test_helper"

class Pay::PayTheFly::ChargeTest < ActiveSupport::TestCase
  test "sync_from_webhook creates charge from valid payment data" do
    user = users(:one)
    pay_customer = user.set_payment_processor(:pay_the_fly)
    wallet = "0x" + "a" * 40
    pay_customer.update!(processor_id: wallet)

    data = {
      "project_id" => "proj1",
      "chain_symbol" => "BSC",
      "tx_hash" => "0x" + "c" * 64,
      "wallet" => wallet,
      "value" => "10000000000000000",
      "fee" => "100000000000000",
      "serial_no" => "ORDER001",
      "tx_type" => 1,
      "confirmed" => true,
      "create_at" => Time.current.to_i
    }

    charge = Pay::PayTheFly::Charge.sync_from_webhook(data)

    assert charge.persisted?
    assert_equal "0x" + "c" * 64, charge.processor_id
    assert_equal 10_000_000_000_000_000, charge.amount
    assert_equal "bsc", charge.currency
    assert_equal "crypto_wallet", charge.payment_method_type
    assert_equal wallet[-4..], charge.last4
    assert_equal data["tx_hash"], charge.data["tx_hash"]
    assert_equal "ORDER001", charge.data["serial_no"]
  end

  test "sync_from_webhook is idempotent" do
    user = users(:one)
    pay_customer = user.set_payment_processor(:pay_the_fly)
    wallet = "0x" + "d" * 40
    pay_customer.update!(processor_id: wallet)

    data = {
      "project_id" => "proj1",
      "chain_symbol" => "BSC",
      "tx_hash" => "0x" + "e" * 64,
      "wallet" => wallet,
      "value" => "10000000000000000",
      "fee" => "0",
      "serial_no" => "ORDER002",
      "tx_type" => 1,
      "confirmed" => true,
      "create_at" => Time.current.to_i
    }

    charge1 = Pay::PayTheFly::Charge.sync_from_webhook(data)
    charge2 = Pay::PayTheFly::Charge.sync_from_webhook(data)

    assert_equal charge1.id, charge2.id
  end

  test "sync_from_webhook returns nil for unknown wallet" do
    data = {
      "tx_hash" => "0x" + "f" * 64,
      "wallet" => "0x" + "9" * 40,
      "value" => "1000000",
      "tx_type" => 1,
      "confirmed" => true,
      "serial_no" => "UNKNOWN"
    }

    assert_nil Pay::PayTheFly::Charge.sync_from_webhook(data)
  end

  test "sync_withdrawal_from_webhook creates withdrawal charge" do
    user = users(:one)
    pay_customer = user.set_payment_processor(:pay_the_fly)
    wallet = "0x" + "b" * 40
    pay_customer.update!(processor_id: wallet)

    data = {
      "project_id" => "proj1",
      "chain_symbol" => "TRON",
      "tx_hash" => "0x" + "1" * 64,
      "wallet" => wallet,
      "value" => "1000000",
      "fee" => "10000",
      "serial_no" => "WD001",
      "tx_type" => 2,
      "confirmed" => true,
      "create_at" => Time.current.to_i
    }

    charge = Pay::PayTheFly::Charge.sync_withdrawal_from_webhook(data)

    assert charge.persisted?
    assert_equal "withdrawal:0x" + "1" * 64, charge.processor_id
    assert_equal 1_000_000, charge.amount
    assert_equal 1_000_000, charge.amount_refunded
    assert charge.withdrawal?
    assert_equal "tron", charge.currency
  end

  test "charged_to returns formatted wallet info" do
    user = users(:one)
    pay_customer = user.set_payment_processor(:pay_the_fly)
    wallet = "0x1234567890abcdef1234567890abcdef12345678"
    pay_customer.update!(processor_id: wallet)

    charge = pay_customer.charges.create!(
      processor_id: "0x" + "a" * 64,
      amount: 1000,
      data: {
        "wallet" => wallet,
        "chain_symbol" => "BSC",
        "payment_method_type" => "crypto_wallet"
      }
    )

    assert_includes charge.charged_to, "BSC"
    assert_includes charge.charged_to, "0x1234"
    assert_includes charge.charged_to, "5678"
  end

  test "explorer_url returns correct BSC URL" do
    user = users(:one)
    pay_customer = user.set_payment_processor(:pay_the_fly)
    pay_customer.update!(processor_id: "0x" + "a" * 40)

    tx_hash = "0x" + "b" * 64
    charge = pay_customer.charges.create!(
      processor_id: tx_hash,
      amount: 1000,
      data: {"tx_hash" => tx_hash, "chain_symbol" => "BSC"}
    )

    assert_equal "https://bscscan.com/tx/#{tx_hash}", charge.explorer_url
  end

  test "explorer_url returns correct TRON URL" do
    user = users(:one)
    pay_customer = user.set_payment_processor(:pay_the_fly)
    pay_customer.update!(processor_id: "0x" + "a" * 40)

    tx_hash = "0x" + "c" * 64
    charge = pay_customer.charges.create!(
      processor_id: tx_hash,
      amount: 1000,
      data: {"tx_hash" => tx_hash, "chain_symbol" => "TRON"}
    )

    assert_equal "https://tronscan.org/#/transaction/#{tx_hash}", charge.explorer_url
  end
end
