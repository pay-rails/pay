module PaymentMethodTests
  extend ActiveSupport::Concern

  included do
    test "make_default! syncs database" do
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

      pm.make_default!

      # Should remain default
      pm.reload
      assert pm.default?
    end

    test "make_default! handles multiple payment methods correctly" do
      # Create three payment methods
      pm1 = @pay_customer.payment_methods.create!(processor_id: "pm_1", payment_method_type: "card", default: true)
      pm2 = @pay_customer.payment_methods.create!(processor_id: "pm_2", payment_method_type: "card", default: false)
      pm3 = @pay_customer.payment_methods.create!(processor_id: "pm_3", payment_method_type: "card", default: false)

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
  end
end
