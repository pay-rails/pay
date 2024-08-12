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

  test "customer with processor" do
    assert_equal @user.payment_processor, @user.payment_processor.api_record
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

  test "subscribe" do
    assert_difference "Pay::Subscription.count" do
      @user.payment_processor.subscribe
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

  test "subscription for different plan" do
    @user.payment_processor.subscription.update(processor_plan: :superior)
    refute @user.payment_processor.subscribed?(processor_plan: "default")
  end

  test "checking for a subscription that is active for a provided plan" do
    @user.payment_processor.subscription.update(processor_plan: "other")
    assert @user.payment_processor.subscribed?(name: "default", processor_plan: "other")
  end

  test "getting a subscription by default name" do
    assert_equal pay_subscriptions(:fake), @user.payment_processor.subscription
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

  test "processor" do
    user = User.new
    assert_nil user.payment_processor

    assert_difference "user.pay_customers.count" do
      user.set_payment_processor :stripe
      assert_equal "stripe", user.payment_processor.processor
    end

    assert_difference "user.pay_customers.count" do
      user.set_payment_processor :braintree
      assert_equal "braintree", user.payment_processor.processor
    end

    assert_difference "user.pay_customers.count" do
      user.set_payment_processor :paddle_billing
      assert_equal "paddle_billing", user.payment_processor.processor
    end

    assert_difference "user.pay_customers.count" do
      user.set_payment_processor :paddle_classic
      assert_equal "paddle_classic", user.payment_processor.processor
    end

    assert_difference "user.pay_customers.count" do
      user.set_payment_processor :fake_processor, allow_fake: true
      assert_equal "fake_processor", user.payment_processor.processor
    end
  end
end
