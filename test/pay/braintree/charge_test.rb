require "test_helper"

class Pay::Braintree::ChargeTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:braintree)
    @pay_customer.update(processor_id: nil)
    @pay_customer.charges.delete_all
    @pay_customer.payment_methods.delete_all
    @pay_customer.subscriptions.delete_all
  end

  test "can partially refund a transaction" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"

    charge = @pay_customer.charge(29_00)
    assert charge.present?

    charge.refund!(10_00)
    assert_equal 10_00, charge.amount_refunded
  end

  test "can fully refund a transaction" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"

    charge = @pay_customer.charge(37_00)
    assert charge.present?

    charge.refund!
    assert_equal 37_00, charge.amount_refunded
  end

  test "braintree saves currency on charge" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    charge = @pay_customer.charge(29_00)
    assert_equal "USD", charge.currency
  end
end
