require "test_helper"

class Pay::Braintree::ChargeTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:braintree)
    @pay_customer.update(processor_id: nil)
    @pay_customer.charges.delete_all
    @pay_customer.payment_methods.delete_all
    @pay_customer.subscriptions.delete_all
  end

  test "refunding an unsettled transaction voids it" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    charge = @pay_customer.charge(29_00)

    charge.refund!
    assert_equal 29_00, charge.reload.amount_refunded
    assert_equal "voided", charge.api_record.status
  end

  test "partially refunding an unsettled transaction raises" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    charge = @pay_customer.charge(29_00)

    error = assert_raises(Pay::Braintree::Error) { charge.refund!(10_00) }
    assert_match "until it settles", error.message
    assert_nil charge.reload.amount_refunded
  end

  test "refunds a settled transaction" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    charge = @pay_customer.charge(29_00)
    Pay.braintree_gateway.testing.settle(charge.processor_id)

    charge.refund!(10_00)
    charge.refund!
    assert_equal 29_00, charge.reload.amount_refunded
  end

  test "refunds zero-decimal currencies in the currency's main unit" do
    charge = settled_charge(amount: 1000, currency: "JPY")
    ::Braintree::TransactionGateway.any_instance.expects(:refund).with("abc", "1000").returns(stub(success?: true))
    charge.refund!
    assert_equal 1000, charge.amount_refunded
  end

  test "partial refunds add up" do
    charge = settled_charge(amount: 19_99)
    ::Braintree::TransactionGateway.any_instance.expects(:refund).with("abc", "5.00").returns(stub(success?: true))
    ::Braintree::TransactionGateway.any_instance.expects(:refund).with("abc", "3.00").returns(stub(success?: true))
    charge.refund!(5_00)
    charge.refund!(3_00)
    assert_equal 8_00, charge.amount_refunded
  end

  test "refunding without an amount refunds what's left" do
    charge = settled_charge(amount: 19_99, amount_refunded: 5_00)
    ::Braintree::TransactionGateway.any_instance.expects(:refund).with("abc", "14.99").returns(stub(success?: true))
    charge.refund!
    assert charge.full_refund?
  end

  test "braintree saves currency on charge" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    charge = @pay_customer.charge(29_00)
    assert_equal "USD", charge.currency
  end

  private

  def settled_charge(**attributes)
    @pay_customer.charges.create!(processor_id: "abc", currency: "USD", **attributes).tap do |charge|
      charge.stubs(:api_record).returns(stub(status: "settled"))
    end
  end
end
