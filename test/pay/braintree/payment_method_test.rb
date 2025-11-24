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

    # Mock the gateway method and Braintree API call
    result = Struct.new(:success?).new(true)
    mock_gateway = mock("gateway")
    mock_customer_gateway = mock("customer_gateway")

    pm2.stubs(:gateway).returns(mock_gateway)
    mock_gateway.expects(:customer).returns(mock_customer_gateway)
    mock_customer_gateway.expects(:update).with(
      @pay_customer.processor_id,
      {default_payment_method_token: "pm_new"}
    ).returns(result)

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
    result = Struct.new(:success?).new(true)
    mock_gateway = mock("gateway")
    mock_customer_gateway = mock("customer_gateway")

    pm3.stubs(:gateway).returns(mock_gateway)
    mock_gateway.stubs(:customer).returns(mock_customer_gateway)
    mock_customer_gateway.stubs(:update).returns(result)

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
    result = Struct.new(:success?).new(false)
    mock_gateway = mock("gateway")
    mock_customer_gateway = mock("customer_gateway")

    pm.stubs(:gateway).returns(mock_gateway)
    mock_gateway.stubs(:customer).returns(mock_customer_gateway)
    mock_customer_gateway.stubs(:update).returns(result)

    # Should raise error
    assert_raises(Pay::Braintree::Error) do
      pm.make_default!
    end

    # Verify database was not updated
    pm.reload
    refute pm.default?
  end
end
