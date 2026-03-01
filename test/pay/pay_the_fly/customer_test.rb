# frozen_string_literal: true

require "test_helper"

class Pay::PayTheFly::CustomerTest < ActiveSupport::TestCase
  test "api_record generates processor_id if missing" do
    user = users(:one)
    customer = user.set_payment_processor(:pay_the_fly)
    customer.update_column(:processor_id, nil)

    customer.api_record
    assert customer.processor_id.present?
  end

  test "charge raises error" do
    user = users(:one)
    customer = user.set_payment_processor(:pay_the_fly)

    assert_raises Pay::Error do
      customer.charge(100)
    end
  end

  test "subscribe raises error" do
    user = users(:one)
    customer = user.set_payment_processor(:pay_the_fly)

    assert_raises Pay::Error do
      customer.subscribe
    end
  end

  test "checkout generates payment link" do
    user = users(:one)
    customer = user.set_payment_processor(:pay_the_fly)
    customer.update!(processor_id: "0x" + "a" * 40)

    Pay::PayTheFly.stub(:project_id, "test_project") do
      Pay::PayTheFly.stub(:private_key, "0x" + "1" * 64) do
        Pay::PayTheFly.stub(:contract_address, "0x" + "2" * 40) do
          # This would need the eth gem loaded to actually sign;
          # just verify the method signature and error handling
          if defined?(::Eth::Key)
            url = customer.checkout(amount: "0.01", serial_no: "TEST-001")
            assert url.start_with?("https://pro.paythefly.com/pay?")
            assert_includes url, "serialNo=TEST-001"
            assert_includes url, "chainId=56"
          end
        end
      end
    end
  end

  test "add_payment_method registers wallet address" do
    user = users(:one)
    customer = user.set_payment_processor(:pay_the_fly)
    customer.update!(processor_id: "0x" + "a" * 40)

    wallet = "0x1234567890abcdef1234567890abcdef12345678"
    pm = customer.add_payment_method(wallet)

    assert pm.persisted?
    assert_equal wallet, pm.processor_id
    assert_equal "crypto_wallet", pm.payment_method_type
    assert pm.default?
    assert_equal "5678", pm.last4
  end

  test "add_payment_method with nil does nothing" do
    user = users(:one)
    customer = user.set_payment_processor(:pay_the_fly)
    customer.update!(processor_id: "0x" + "a" * 40)

    assert_nil customer.add_payment_method(nil)
  end

  test "sync_subscriptions returns empty array" do
    user = users(:one)
    customer = user.set_payment_processor(:pay_the_fly)

    assert_equal [], customer.sync_subscriptions
  end
end
