require "test_helper"

class Pay::Paddle::Webhooks::SubscriptionPaymentSucceededTest < ActiveSupport::TestCase
  setup do
    @data = JSON.parse(File.read("test/support/fixtures/paddle/subscription_payment_succeeded.json"))
  end

  test "a charge is created" do
    @user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: @data["user_id"])

    assert_difference "Pay.charge_model.count" do
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new(@data)
    end

    charge = Pay.charge_model.last
    assert_equal 10539, charge.amount
    assert_equal @data["payment_method"], charge.card_type
    assert_equal @data["receipt_url"], charge.paddle_receipt_url
  end

  test "a charge isn't created if no corresponding user can be found" do
    @user = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: "does-not-exist")

    assert_no_difference "Pay.charge_model.count" do
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new(@data)
    end
  end

  test "a charge isn't created if it already exists" do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe, processor_id: @data["user_id"])

    @user.charges.create!(amount: 100, processor: :paddle, processor_id: @data["subscription_payment_id"], card_type: @data["payment_method"])

    assert_no_difference "Pay.charge_model.count" do
      Pay::Paddle::Webhooks::SubscriptionPaymentSucceeded.new(@data)
    end
  end

end
