require "test_helper"
require "rake"

class PayRakeTest < ActiveSupport::TestCase
  setup do
    load File.expand_path("../../lib/tasks/pay.rake", __dir__)
  end

  test "sync_default syncs a Stripe customer's payment method on its Connect account" do
    pay_customer = pay_customers(:stripe)
    pay_customer.update!(stripe_account: "acct_123")
    pay_customer.stubs(:api_record).returns(::Stripe::Customer.construct_from(invoice_settings: {default_payment_method: "pm_1"}))

    Pay::Stripe::PaymentMethod.expects(:sync).with("pm_1", stripe_account: "acct_123", customer: pay_customer)

    capture_io { sync_default_payment_method(pay_customer) }
  end
end
