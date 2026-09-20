require "test_helper"

class Pay::CustomerTest < ActiveSupport::TestCase
  setup do
    @user = users(:fake)
  end

  test "customer name" do
    assert_equal "Fake User", @user.payment_processor.customer_name
  end

  test "customer with a pay_customer_name" do
    @user.define_singleton_method(:pay_customer_name) { "Pay Customer Name" }
    assert_equal "Pay Customer Name", @user.payment_processor.customer_name
  end

  test "email" do
    assert_equal "fake@example.org", @user.payment_processor.email
  end

  test "email after owner deleted" do
    @user.destroy
    assert_nil @user.payment_processor.reload.email
  end

  test "customer with invalid processor" do
    assert_raises NameError do
      @user.set_payment_processor "pants"
    end
  end

  test "customer without processor" do
    assert_raises StandardError do
      users(:none).payment_processor.api_record
    end
  end

  test "updating a card" do
    assert @user.payment_processor.update_payment_method("a1b2c3")
  end

  test "updating a card without a processor" do
    assert_raises StandardError do
      users(:none).payment_processor.update_payment_method("whoops")
    end
  end

  test "subscribed? with no subscription" do
    @user.payment_processor.subscriptions.delete_all
    refute @user.payment_processor.subscribed?
  end

  test "subscribed? with active subscription" do
    @user.payment_processor.subscription.update(status: :active)
    assert @user.payment_processor.subscribed?
  end

  test "subscribed? with incomplete subscription" do
    @user.payment_processor.subscription.update(status: :incomplete)
    refute @user.payment_processor.subscribed?
  end

  test "subscribed? with past_due subscription" do
    @user.payment_processor.subscription.update(status: :past_due)
    refute @user.payment_processor.subscribed?
  end

  test "subscribed? with canceled subscription" do
    @user.payment_processor.subscription.update(status: :canceled, ends_at: 1.day.ago)
    refute @user.payment_processor.subscribed?
  end

  test "subscribed? with canceled subscription on grace period" do
    @user.payment_processor.subscription.update(status: :canceled, ends_at: 1.day.from_now)
    refute @user.payment_processor.subscribed?
  end

  test "subscribed? with different plan" do
    @user.payment_processor.subscription.update(processor_plan: :superior)
    refute @user.payment_processor.subscribed?(processor_plan: "default")
  end

  test "subscription with active subscription" do
    subscription = @user.payment_processor.subscriptions.last
    assert_equal subscription, @user.payment_processor.subscription
  end

  test "subscription with inactive subscription" do
    subscription = @user.payment_processor.subscriptions.last
    subscription.update!(ends_at: 10.days.ago)
    assert_equal subscription, @user.payment_processor.subscription
  end

  test "checking for a subscription that is active for a provided plan" do
    @user.payment_processor.subscription.update(processor_plan: "other")
    assert @user.payment_processor.subscribed?(name: "default", processor_plan: "other")
  end

  test "on_trial? with no plan" do
    @user.payment_processor.subscription.update(trial_ends_at: 7.days.from_now)
    assert @user.payment_processor.on_trial?
  end

  test "on_trial? with plan matching the subscription plan" do
    @user.payment_processor.subscription.update(trial_ends_at: 7.days.from_now)
    assert @user.payment_processor.on_trial?(plan: "default")
  end

  test "on_trial? with plan different than the subscription plan" do
    @user.payment_processor.subscription.update(trial_ends_at: 7.days.from_now, processor_plan: "PROCESSOR_PLAN")
    refute @user.payment_processor.on_trial?(plan: "OTHERPLAN")
  end

  test "on_trial_or_subscribed? with no plan" do
    @user.payment_processor.subscription.update(trial_ends_at: 7.days.from_now)
    assert @user.payment_processor.on_trial_or_subscribed?
  end

  test "on_trial_or_subscribed? with a subscription that is active for another plan" do
    @user.payment_processor.subscription.update(processor_plan: "superior")
    refute @user.payment_processor.on_trial_or_subscribed?(name: "default", processor_plan: "default")
  end

  test "on_trial_or_subscribed? with a subscription that is active for a provided plan" do
    assert @user.payment_processor.on_trial_or_subscribed?(name: "default", processor_plan: "default")
  end

  test "switching payment processor clears processor id" do
    @user.set_payment_processor :stripe, processor_id: "1"
    assert_equal "1", @user.payment_processor.processor_id

    @user.set_payment_processor :braintree
    assert_nil @user.payment_processor.processor_id
  end

  test "active customers" do
    results = Pay::Customer.active
    assert_includes results, pay_customers(:stripe)
    refute_includes results, pay_customers(:deleted)
  end

  test "deleted customers" do
    assert_includes Pay::Customer.deleted, pay_customers(:deleted)
  end

  test "active?" do
    assert pay_customers(:stripe).active?
  end

  test "deleted?" do
    assert pay_customers(:deleted).deleted?
  end

  test "update_api_record with a promotion code" do
    pay_customer = pay_customers(:fake)
    assert pay_customer.update_api_record(promotion_code: "promo_xxx123")
  end

  test "subscription prefers an active subscription over a newer canceled one" do
    pay_customer = pay_customers(:fake)
    active = pay_customer.subscriptions.first
    canceled = pay_customer.subscriptions.create!(processor_id: "fake_2", name: "default", processor_plan: "default", status: "canceled", ends_at: 1.day.ago, created_at: 1.day.from_now)

    assert_equal active, pay_customer.subscription
    assert_not_equal canceled, pay_customer.subscription
  end

  test "subscription prefers a paused subscription over a newer canceled one" do
    pay_customer = pay_customers(:fake)
    paused = pay_customer.subscriptions.first
    paused.update!(status: "paused")
    pay_customer.subscriptions.create!(processor_id: "fake_2", name: "default", processor_plan: "default", status: "canceled", ends_at: 1.day.ago, created_at: 1.day.from_now)

    assert_equal paused, pay_customer.subscription
  end

  test "subscription falls back to the most recent subscription when none are active" do
    pay_customer = pay_customers(:fake)
    pay_customer.subscriptions.first.update!(status: "canceled", ends_at: 2.days.ago)
    newer = pay_customer.subscriptions.create!(processor_id: "fake_2", name: "default", processor_plan: "default", status: "canceled", ends_at: 1.day.ago, created_at: 1.day.from_now)

    assert_equal newer, pay_customer.subscription
  end

  test "subscription returns nil when there are no subscriptions for the name" do
    assert_nil pay_customers(:fake).subscription(name: "nonexistent")
  end

  test "not_fake scope" do
    assert_not_includes Pay::Customer.not_fake_processor, pay_customers(:fake)
    assert_includes Pay::Customer.not_fake_processor, pay_customers(:stripe)
  end
end
