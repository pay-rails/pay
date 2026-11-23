require "test_helper"

class Pay::Braintree::ChargeTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:braintree)
    @pay_customer.update(processor_id: nil)
    @pay_customer.charges.delete_all
    @pay_customer.payment_methods.delete_all
    @pay_customer.subscriptions.delete_all
  end

  # Braintree only refunds settled transactions, and sandbox transactions settle in a nightly batch
  test "refunding an unsettled transaction raises" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    charge = @pay_customer.charge(29_00)

    error = assert_raises(Pay::Braintree::Error) { charge.refund!(10_00) }
    assert_match "unless it is settled", error.message
    assert_nil charge.reload.amount_refunded
  end

  test "refunds zero-decimal currencies in the currency's main unit" do
    charge = @pay_customer.charges.create!(processor_id: "abc", amount: 1000, currency: "JPY")
    ::Braintree::TransactionGateway.any_instance.expects(:refund).with("abc", "1000").returns(stub(success?: true))
    charge.refund!
    assert_equal 1000, charge.amount_refunded
  end

  test "partial refunds add up" do
    charge = @pay_customer.charges.create!(processor_id: "abc", amount: 19_99, currency: "USD")
    ::Braintree::TransactionGateway.any_instance.expects(:refund).with("abc", "5.00").returns(stub(success?: true))
    ::Braintree::TransactionGateway.any_instance.expects(:refund).with("abc", "3.00").returns(stub(success?: true))
    charge.refund!(5_00)
    charge.refund!(3_00)
    assert_equal 8_00, charge.amount_refunded
  end

  test "refunding without an amount refunds what's left" do
    charge = @pay_customer.charges.create!(processor_id: "abc", amount: 19_99, amount_refunded: 5_00, currency: "USD")
    ::Braintree::TransactionGateway.any_instance.expects(:refund).with("abc", "14.99").returns(stub(success?: true))
    charge.refund!
    assert charge.full_refund?
  end

  test "braintree saves currency on charge" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    charge = @pay_customer.charge(29_00)
    assert_equal "USD", charge.currency
  end
end
