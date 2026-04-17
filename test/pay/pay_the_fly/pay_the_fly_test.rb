# frozen_string_literal: true

require "test_helper"
require "digest/keccak"

class Pay::PayTheFlyTest < ActiveSupport::TestCase
  # ─── Keccak-256 vs SHA3-256 ─────────────────────────────────────────
  # This is the single most critical test. EIP-712 signatures WILL break
  # if you accidentally use SHA3-256 instead of Keccak-256.

  test "keccak256 produces correct hash (NOT SHA3-256)" do
    # Known test vector: keccak256("") = c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
    empty_hash = Pay::PayTheFly.keccak256("")
    assert_equal "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
      empty_hash.unpack1("H*")

    # SHA3-256("") would be a6e167...  — completely different!
    refute_equal "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a",
      empty_hash.unpack1("H*"),
      "CRITICAL: You are using SHA3-256 instead of Keccak-256!"
  end

  test "keccak256 of 'hello' matches known vector" do
    # keccak256("hello") = 1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8
    hash = Pay::PayTheFly.keccak256("hello")
    assert_equal "1c8aff950685c2ed4bc3174f3472287b56d9517b9c948127319a09a7a36deac8",
      hash.unpack1("H*")
  end

  # ─── ABI Encoding ───────────────────────────────────────────────────

  test "abi_encode encodes address as left-padded 32 bytes" do
    result = Pay::PayTheFly.abi_encode(
      [:address],
      ["0x0000000000000000000000000000000000000000"]
    )
    assert_equal 32, result.bytesize
    assert_equal "\x00" * 32, result.b
  end

  test "abi_encode encodes uint256 correctly" do
    result = Pay::PayTheFly.abi_encode([:uint256], [1])
    assert_equal 32, result.bytesize
    expected = "\x00" * 31 + "\x01"
    assert_equal expected.b, result
  end

  test "abi_encode encodes large uint256" do
    # 10^18 = 0xDE0B6B3A7640000
    result = Pay::PayTheFly.abi_encode([:uint256], [10**18])
    hex = result.unpack1("H*")
    assert_equal "0000000000000000000000000000000000000000000000000de0b6b3a7640000", hex
  end

  # ─── Chain Configuration ────────────────────────────────────────────

  test "CHAINS has BSC and TRON" do
    assert Pay::PayTheFly::CHAINS.key?(56)
    assert Pay::PayTheFly::CHAINS.key?(728126428)

    bsc = Pay::PayTheFly::CHAINS[56]
    assert_equal "BSC", bsc[:symbol]
    assert_equal 18, bsc[:decimals]
    assert_equal "0x0000000000000000000000000000000000000000", bsc[:native_token]

    tron = Pay::PayTheFly::CHAINS[728126428]
    assert_equal "TRON", tron[:symbol]
    assert_equal 6, tron[:decimals]
    assert_equal "T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb", tron[:native_token]
  end

  # ─── Unit Conversion ────────────────────────────────────────────────

  test "to_wei converts BSC amounts (18 decimals)" do
    assert_equal 10_000_000_000_000_000, Pay::PayTheFly.to_wei("0.01", 18)
    assert_equal 1_000_000_000_000_000_000, Pay::PayTheFly.to_wei("1", 18)
    assert_equal 1_500_000_000_000_000_000, Pay::PayTheFly.to_wei("1.5", 18)
  end

  test "to_wei converts TRON amounts (6 decimals)" do
    assert_equal 10_000, Pay::PayTheFly.to_wei("0.01", 6)
    assert_equal 1_000_000, Pay::PayTheFly.to_wei("1", 6)
  end

  test "from_wei converts back correctly" do
    assert_equal BigDecimal("0.01"), Pay::PayTheFly.from_wei(10_000_000_000_000_000, 18)
    assert_equal BigDecimal("1"), Pay::PayTheFly.from_wei(1_000_000, 6)
  end

  test "chain_for finds by ID and symbol" do
    assert_equal "BSC", Pay::PayTheFly.chain_for(56)[:symbol]
    assert_equal "TRON", Pay::PayTheFly.chain_for(:TRON)[:symbol]
    assert_nil Pay::PayTheFly.chain_for(999)
  end

  # ─── Webhook Signature Verification ─────────────────────────────────

  test "verify_webhook_signature with valid data" do
    project_key = "test_project_key_123"
    data = '{"project_id":"proj1","tx_hash":"0xabc"}'
    timestamp = "1709280000"

    # Stub project_key
    Pay::PayTheFly.stub(:project_key, project_key) do
      expected_sig = OpenSSL::HMAC.hexdigest("SHA256", project_key, "#{data}.#{timestamp}")

      assert Pay::PayTheFly.verify_webhook_signature(
        data: data,
        timestamp: timestamp,
        signature: expected_sig
      )
    end
  end

  test "verify_webhook_signature rejects tampered data" do
    project_key = "test_project_key_123"
    data = '{"project_id":"proj1","tx_hash":"0xabc"}'
    timestamp = "1709280000"

    Pay::PayTheFly.stub(:project_key, project_key) do
      assert_not Pay::PayTheFly.verify_webhook_signature(
        data: data,
        timestamp: timestamp,
        signature: "invalid_signature_hex"
      )
    end
  end

  test "verify_webhook_signature rejects modified timestamp" do
    project_key = "test_project_key_123"
    data = '{"project_id":"proj1","tx_hash":"0xabc"}'
    original_timestamp = "1709280000"
    tampered_timestamp = "1709280001"

    Pay::PayTheFly.stub(:project_key, project_key) do
      sig = OpenSSL::HMAC.hexdigest("SHA256", project_key, "#{data}.#{original_timestamp}")

      assert_not Pay::PayTheFly.verify_webhook_signature(
        data: data,
        timestamp: tampered_timestamp,
        signature: sig
      )
    end
  end

  # ─── EIP-712 Domain ─────────────────────────────────────────────────

  test "EIP712 constants are correct" do
    assert_equal "PayTheFlyPro", Pay::PayTheFly::EIP712_DOMAIN_NAME
    assert_equal "1", Pay::PayTheFly::EIP712_DOMAIN_VERSION
  end

  test "domain_separator produces 32-byte hash" do
    result = Pay::PayTheFly.domain_separator(
      chain_id: 56,
      verifying_contract: "0x0000000000000000000000000000000000000001"
    )
    assert_equal 32, result.bytesize
  end

  test "domain_separator differs for different chain IDs" do
    ds_bsc = Pay::PayTheFly.domain_separator(
      chain_id: 56,
      verifying_contract: "0x0000000000000000000000000000000000000001"
    )
    ds_tron = Pay::PayTheFly.domain_separator(
      chain_id: 728126428,
      verifying_contract: "0x0000000000000000000000000000000000000001"
    )
    refute_equal ds_bsc, ds_tron
  end

  # ─── Payment Struct Hash ────────────────────────────────────────────

  test "payment_struct_hash produces 32-byte hash" do
    result = Pay::PayTheFly.payment_struct_hash(
      project_id: "test_project",
      token: "0x0000000000000000000000000000000000000000",
      amount: 10_000_000_000_000_000,
      serial_no: "ORDER001",
      deadline: 1709280000
    )
    assert_equal 32, result.bytesize
  end

  test "payment_struct_hash is deterministic" do
    args = {
      project_id: "proj1",
      token: "0x0000000000000000000000000000000000000000",
      amount: 1_000_000,
      serial_no: "ORD-1",
      deadline: 9_999_999_999
    }
    assert_equal Pay::PayTheFly.payment_struct_hash(**args),
      Pay::PayTheFly.payment_struct_hash(**args)
  end

  test "payment_struct_hash differs for different serial_nos" do
    common = {
      project_id: "proj1",
      token: "0x0000000000000000000000000000000000000000",
      amount: 1_000_000,
      deadline: 9_999_999_999
    }
    h1 = Pay::PayTheFly.payment_struct_hash(serial_no: "A", **common)
    h2 = Pay::PayTheFly.payment_struct_hash(serial_no: "B", **common)
    refute_equal h1, h2
  end

  # ─── Withdrawal Struct Hash ─────────────────────────────────────────

  test "withdrawal_struct_hash produces 32-byte hash" do
    result = Pay::PayTheFly.withdrawal_struct_hash(
      user: "0x0000000000000000000000000000000000000001",
      project_id: "test_project",
      token: "0x0000000000000000000000000000000000000000",
      amount: 10_000_000_000_000_000,
      serial_no: "WD001",
      deadline: 1709280000
    )
    assert_equal 32, result.bytesize
  end

  test "withdrawal and payment struct hashes differ for same inputs" do
    payment_hash = Pay::PayTheFly.payment_struct_hash(
      project_id: "proj1",
      token: "0x0000000000000000000000000000000000000000",
      amount: 1_000_000,
      serial_no: "ORD-1",
      deadline: 9_999_999_999
    )
    withdrawal_hash = Pay::PayTheFly.withdrawal_struct_hash(
      user: "0x0000000000000000000000000000000000000001",
      project_id: "proj1",
      token: "0x0000000000000000000000000000000000000000",
      amount: 1_000_000,
      serial_no: "ORD-1",
      deadline: 9_999_999_999
    )
    refute_equal payment_hash, withdrawal_hash
  end
end
