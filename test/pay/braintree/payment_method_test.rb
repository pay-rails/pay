require "test_helper"

class Pay::Braintree::PaymentMethodTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:braintree)
  end

  test "make_default! updates Braintree and syncs database" do
    # Create a default payment method
    pm1 = @pay_customer.payment_methods.create!(
      processor_id: "pm_default",
      payment_method_type: "card",
      default: true
    )

    # Create a second payment method
    pm2 = @pay_customer.payment_methods.create!(
      processor_id: "pm_new",
      payment_method_type: "card",
      default: false
    )

    # Mock the Braintree API call
    mock_customer_gateway(pm2).expects(:update).with(
      @pay_customer.processor_id,
      default_payment_method_token: "pm_new"
    ).returns(braintree_result(success: true))

    # Make pm2 the default
    pm2.make_default!

    # Verify database state
    pm1.reload
    pm2.reload
    refute pm1.default?, "Old default should no longer be default"
    assert pm2.default?, "New payment method should be default"
  end

  test "make_default! returns early if already default" do
    pm = @pay_customer.payment_methods.create!(
      processor_id: "pm_123",
      payment_method_type: "card",
      default: true
    )

    # Should not call any gateway methods
    pm.expects(:gateway).never

    pm.make_default!
  end

  test "make_default! handles multiple payment methods correctly" do
    # Create three payment methods
    pm1 = @pay_customer.payment_methods.create!(processor_id: "pm_1", payment_method_type: "card", default: true)
    pm2 = @pay_customer.payment_methods.create!(processor_id: "pm_2", payment_method_type: "card", default: false)
    pm3 = @pay_customer.payment_methods.create!(processor_id: "pm_3", payment_method_type: "card", default: false)

    # Mock Braintree API call
    mock_customer_gateway(pm3).stubs(:update).returns(braintree_result(success: true))

    # Make pm3 the default
    pm3.make_default!

    # Verify all states
    pm1.reload
    pm2.reload
    pm3.reload
    refute pm1.default?
    refute pm2.default?
    assert pm3.default?
  end

  test "make_default! raises error when Braintree update fails" do
    pm = @pay_customer.payment_methods.create!(
      processor_id: "pm_123",
      payment_method_type: "card",
      default: false
    )

    # Mock Braintree API failure
    mock_customer_gateway(pm).stubs(:update).returns(braintree_result(success: false))

    # Should raise error
    assert_raises(Pay::Braintree::Error) do
      pm.make_default!
    end

    # Verify database was not updated
    pm.reload
    refute pm.default?
  end

  private

  # Replaces the payment method's Braintree gateway so no API calls are made
  def mock_customer_gateway(payment_method)
    mock("customer_gateway").tap do |customer_gateway|
      payment_method.stubs(:gateway).returns(stub(customer: customer_gateway))
    end
  end

  def braintree_result(success:)
    Struct.new(:success?).new(success)
  end
end
