require "test_helper"

class Pay::Paddle::Webhooks::SubscriptionCreatedTest < ActiveSupport::TestCase
  setup do
    @data = JSON.parse(File.read("test/support/fixtures/paddle/subscription_created.json"))
  end

  test "a subscription is created" do
    @user = User.create!(email: "gob@bluth.com")

    assert_difference "Pay.subscription_model.count" do
      Pay::Paddle::Webhooks::SubscriptionCreated.new(@data)
    end

    assert_equal "paddle", @user.reload.processor
    assert_equal @data["user_id"], @user.reload.processor_id

    subscription = Pay.subscription_model.last
    assert_equal @data["quantity"].to_i, subscription.quantity
    assert_equal @data["subscription_plan_id"], subscription.processor_plan
    assert_equal @data["update_url"], subscription.update_url
    assert_equal @data["cancel_url"], subscription.cancel_url
    assert_equal DateTime.parse(@data["next_bill_date"]), subscription.trial_ends_at
    assert_nil subscription.ends_at
  end

  test "a subscription isn't created if no corresponding owner can be found" do
    @user = User.create!(email: "gob@bluth.com")
    @data["passthrough"] = "does-not-exist"

    assert_no_difference "Pay.subscription_model.count" do
      Pay::Paddle::Webhooks::SubscriptionCreated.new(@data)
    end
  end
end