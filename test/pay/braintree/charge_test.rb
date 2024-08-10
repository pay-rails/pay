require "test_helper"
require "minitest/mock"

class Pay::Braintree::Charge::Test < ActiveSupport::TestCase
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

  test "you can ask the charge for the type" do
    assert pay_customers(:stripe).charges.new.stripe?
    refute pay_customers(:braintree).charges.new.stripe?

    assert pay_customers(:braintree).charges.new.braintree?
    refute pay_customers(:braintree).charges.new.stripe?

    assert pay_customers(:paddle_classic).charges.new.paddle_classic?
    refute pay_customers(:paddle_classic).charges.new.stripe?

    assert pay_customers(:fake).charges.new.fake_processor?
    refute pay_customers(:fake).charges.new.stripe?
  end

  test "braintree saves currency on charge" do
    @pay_customer.update_payment_method "fake-valid-visa-nonce"
    charge = @pay_customer.charge(29_00)
    assert_equal "USD", charge.currency
  end
end
