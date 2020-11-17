require "test_helper"

class Pay::Paddle::Billable::Test < ActiveSupport::TestCase
  setup do
    @billable = User.create!(email: "gob@bluth.com", processor: :paddle, processor_id: "17368056")
    @billable.subscriptions.create!(
      processor: :paddle,
      processor_id: "3576390",
      name: "default",
      processor_plan: "some-plan",
      status: "active"
    )
  end

  test "paddle can create a charge" do
    charge = @billable.charge(1000, {charge_name: "Test"})
    assert_equal Pay::Charge, charge.class
    assert_equal 1000, charge.amount
  end

  test "paddle cannot create a charge without charge_name" do
    assert_raises(Pay::Error) { @billable.charge(1000) }
  end

  test "retriving a paddle subscription" do
    subscription = ::PaddlePay::Subscription::User.list({subscription_id: "3576390"}, {}).try(:first)
    assert_equal @billable.paddle_subscription("3576390").subscription_id, subscription[:subscription_id]
  end
end
