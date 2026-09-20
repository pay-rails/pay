require "test_helper"

class Pay::LemonSqueezy::Subscription::Test < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:lemon_squeezy)
  end

  test "lemon squeezy api_record" do
    assert_equal @pay_customer.subscription.api_record.class, ::LemonSqueezy::Subscription
    assert_equal "active", @pay_customer.subscription.status
  end

  test "lemon squeezy can swap plans" do
    @pay_customer.subscription.swap("174873", variant_id: "225676")
    assert_equal 225676, @pay_customer.subscription.api_record.variant_id
    assert_equal "active", @pay_customer.subscription.status
  end

  test "lemon squeezy on_trial" do
    subscription = @pay_customer.subscription
    subscription.update!(status: :trialing, trial_ends_at: 1.month.from_now)
    assert subscription.on_trial?
    assert_includes Pay::Subscription.on_trial, subscription
  end

  test "lemon squeezy sync normalizes on_trial to trialing" do
    subscription = sync_lemon_squeezy_subscription("status" => "on_trial", "trial_ends_at" => "2030-01-24T12:43:48.000000Z")
    assert_equal "trialing", subscription.status
    assert subscription.on_trial?
    assert subscription.active?
  end

  test "lemon squeezy sync normalizes cancelled to canceled and removes the customer's payment methods" do
    @pay_customer.payment_methods.create!(processor_id: "pm_ls", payment_method_type: "card")
    subscription = sync_lemon_squeezy_subscription("status" => "cancelled", "ends_at" => "2030-01-24T12:43:48.000000Z")
    assert_equal "canceled", subscription.status
    assert_empty @pay_customer.payment_methods.reload
  end

  test "lemon squeezy sync stores the pause end in pause_resumes_at" do
    subscription = sync_lemon_squeezy_subscription("status" => "paused", "pause" => {"mode" => "void", "resumes_at" => "2030-01-24T12:43:48.000000Z"})
    assert subscription.paused?
    assert_equal Time.parse("2030-01-24T12:43:48Z"), subscription.pause_resumes_at
    assert_nil subscription.pause_starts_at
  end

  test "lemon squeezy resume unpauses a paused subscription" do
    subscription = @pay_customer.subscription
    subscription.update!(status: :paused, pause_resumes_at: 1.month.from_now)
    ::LemonSqueezy::Subscription.expects(:unpause).with(id: subscription.processor_id)
    ::LemonSqueezy::Subscription.expects(:uncancel).never

    subscription.resume

    assert_equal "active", subscription.status
    assert_nil subscription.pause_resumes_at
  end

  private

  def sync_lemon_squeezy_subscription(attributes)
    json = json_fixture("lemon_squeezy/subscription_created").deep_merge("data" => {"attributes" => attributes})
    object = Pay::LemonSqueezy.construct_from_webhook_event(json)
    @pay_customer.update!(processor_id: object.customer_id)
    Pay::LemonSqueezy::Subscription.sync(object.id, object: object)
  end
end
