require "test_helper"

class Pay::Stripe::Webhooks::ChargeSucceededTest < ActiveSupport::TestCase
  setup do
    @event = stripe_event("test/support/fixtures/stripe/charge_succeeded_event.json")
  end

  test "a charge is created" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
    ::Stripe::Charge.stubs(:retrieve).returns fake_stripe_charge

    assert_difference "Pay.charge_model.count" do
      Pay::Stripe::Webhooks::ChargeSucceeded.new.call(@event)
    end

    charge = Pay.charge_model.last
    assert_equal 500, charge.amount
    assert_equal "4444", charge.card_last4
    assert_equal "Visa", charge.card_type
    assert_equal "1", charge.card_exp_month
    assert_equal "2019", charge.card_exp_year
    assert_equal "usd", charge.currency
  end

  test "a charge isn't created if no corresponding user can be found" do
    ::Stripe::Charge.stubs(:retrieve).returns fake_stripe_charge
    assert_no_difference "Pay.charge_model.count" do
      Pay::Stripe::Webhooks::ChargeSucceeded.new.call(@event)
    end
  end

  test "a charge isn't created if it already exists" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
    @user.charges.create!(amount: 100, processor: :stripe, processor_id: "ch_chargeid", card_type: "Visa", card_exp_month: 1, card_exp_year: 2019, card_last4: "4444")
    ::Stripe::Charge.stubs(:retrieve).returns fake_stripe_charge

    assert_no_difference "Pay.charge_model.count" do
      Pay::Stripe::Webhooks::ChargeSucceeded.new.call(@event)
    end
  end

  test "stripe charge gets associated with subscription" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)
    subscription = @user.subscriptions.create(name: "default", processor: :stripe, processor_id: "12345", processor_plan: "default", quantity: 1, status: "active")
    invoice = OpenStruct.new(subscription: "12345")
    charge = OpenStruct.new(
      amount: 15_00,
      application_fee_amount: 0,
      created: Time.current.to_i,
      customer: @event.data.object.customer,
      currency: "usd",
      id: "abcd",
      invoice: "in_abcd",
      payment_method_details: OpenStruct.new(card: OpenStruct.new(last4: "1234", brand: "Visa", exp_month: 1, exp_year: 2021)),
      stripe_account: nil
    )
    ::Stripe::Charge.stubs(:retrieve).returns charge

    ::Stripe::Invoice.stub :retrieve, invoice do
      Pay::Stripe::Webhooks::ChargeSucceeded.new.call(@event)
      assert_equal subscription, Pay.charge_model.find_by(processor: :stripe, processor_id: "abcd").subscription
    end
  end

  def fake_stripe_charge(**values)
    values.reverse_merge!(@event.data.object.to_hash)
    ::Stripe::Subscription.construct_from(values)
  end
end
