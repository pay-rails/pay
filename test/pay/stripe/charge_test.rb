require "test_helper"

class Pay::Stripe::ChargeTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: "cus_1234")
  end

  test "sync stripe charge by ID" do
    ::Stripe::Charge.stubs(:retrieve).returns(fake_stripe_charge)

    assert_difference "Pay::Charge.count" do
      Pay::Stripe::Charge.sync("123")
    end
  end

  test "sync associates charge with stripe subscription" do
    pay_subscription = @user.subscriptions.create!(processor: :stripe, processor_id: "sub_1234", name: "default", processor_plan: "some-plan", status: "active")
    fake_invoice = ::Stripe::Invoice.construct_from(subscription: "sub_1234")
    pay_charge = Pay::Stripe::Charge.sync("123", object: fake_stripe_charge(invoice: fake_invoice))
    assert_equal pay_subscription, pay_charge.subscription
  end

  private

  def fake_stripe_charge(**values)
    values.reverse_merge!(
      id: "ch_123",
      customer: "cus_1234",
      amount: 19_00,
      amount_refunded: nil,
      application_fee_amount: 0,
      created: 1546332337,
      currency: "usd",
      invoice: nil,
      payment_method_details: {
        card: {
          exp_month: 1,
          exp_year: 2021,
          last4: "4242",
          brand: "Visa"
        }
      },
      stripe_account: nil
    )
    ::Stripe::Charge.construct_from(values)
  end
end
