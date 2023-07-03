require "test_helper"

class Pay::LemonSqueezy::Webhooks::SubscriptionCreatedTest < ActiveSupport::TestCase
  setup do
    @data = OpenStruct.new JSON.parse(File.read("test/support/fixtures/lemon_squeezy/subscription_created.json"))
    @user = users(:lemon_squeezy)
  end

  test "paddle passthrough" do
    json = JSON.parse Pay::LemonSqueezy.passthrough(owner: @user, foo: :bar)
    assert_equal "bar", json["foo"]
    assert_equal @user, GlobalID::Locator.locate_signed(json["owner_sgid"])
  end

  test "a subscription is created" do
    assert_difference "Pay::Subscription.count" do
      @data.passthrough = Pay::LemonSqueezy.passthrough(owner: @user)
      Pay::LemonSqueezy::Webhooks::SubscriptionCreated.new.call(@data)
    end

    @user.reload

    assert_equal "lemon_squeezy", @user.payment_processor.processor
    assert_equal @data.user_id, @user.payment_processor.processor_id

    subscription = Pay::Subscription.last
    assert_equal @data.quantity.to_i, subscription.quantity
    assert_equal @data.subscription_plan_id, subscription.processor_plan
    assert_equal @data.update_url, subscription.paddle_update_url
    assert_equal @data.cancel_url, subscription.paddle_cancel_url
    assert_equal Time.zone.parse(@data.next_bill_date), subscription.trial_ends_at
    assert_nil subscription.ends_at
  end

  test "a subscription isn't created if no corresponding owner can be found" do
    @data.passthrough = "does-not-exist"

    assert_no_difference "Pay::Subscription.count" do
      Pay::LemonSqueezy::Webhooks::SubscriptionCreated.new.call(@data)
    end
  end
end
