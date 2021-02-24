require "test_helper"

class Pay::FakeProcessor::Subscription::Test < ActiveSupport::TestCase
  setup do
    @billable = User.create!(email: "gob@bluth.com", processor: :fake_processor, processor_id: "17368056")
    @subscription = @billable.subscribe
  end

  test "fake processor subscription" do
    assert_equal @subscription, @subscription.processor_subscription
  end

  test "fake processor cancel" do
    freeze_time do
      @subscription.cancel
      assert_equal Time.current.end_of_month.to_date, @subscription.ends_at.to_date
    end
  end

  test "fake processor cancel_now!" do
    @subscription.cancel_now!
    assert_not @subscription.active?
  end

  test "fake processor on_grace_period?" do
    freeze_time do
      @subscription.cancel
      assert @subscription.on_grace_period?
    end
  end

  test "fake processor resume" do
    freeze_time do
      @subscription.cancel
      assert_not_nil @subscription.ends_at
      @subscription.resume
      assert_nil @subscription.ends_at
    end
  end

  test "fake processor swap" do
    @subscription.swap("another_plan")
    assert_equal "another_plan", @subscription.processor_plan
  end
end
