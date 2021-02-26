require "test_helper"

class Pay::Stripe::Webhooks::ChargeSucceededTest < ActiveSupport::TestCase
  setup do
    @event = OpenStruct.new
    @event.data = JSON.parse(File.read("test/support/fixtures/stripe/charge_succeeded_event.json"), object_class: OpenStruct)
  end

  test "a charge is created" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)

    assert_difference "Pay.charge_model.count" do
      Pay::Stripe::Webhooks::ChargeSucceeded.new.call(@event)
    end

    charge = Pay.charge_model.last
    assert_equal 500, charge.amount
    assert_equal "4444", charge.card_last4
    assert_equal "Visa", charge.card_type
    assert_equal "1", charge.card_exp_month
    assert_equal "2019", charge.card_exp_year
  end

  test "a charge isn't created if no corresponding user can be found" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: "does-not-exist")

    assert_no_difference "Pay.charge_model.count" do
      Pay::Stripe::Webhooks::ChargeSucceeded.new.call(@event)
    end
  end

  test "a charge isn't created if it already exists" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @event.data.object.customer)

    @user.charges.create!(amount: 100, processor: :stripe, processor_id: "ch_chargeid", card_type: "Visa", card_exp_month: 1, card_exp_year: 2019, card_last4: "4444")

    assert_no_difference "Pay.charge_model.count" do
      Pay::Stripe::Webhooks::ChargeSucceeded.new.call(@event)
    end
  end
end
