require "test_helper"

class Pay::CustomerTest < ActiveSupport::TestCase
  setup do
    @user = users(:fake)
  end

  test "customer name" do
    assert_equal "Fake User", @user.pay_payment_processor.customer_name
  end

  test "customer with a pay_customer_name" do
    @user.define_singleton_method(:pay_customer_name) { "Pay Customer Name" }
    assert_equal "Pay Customer Name", @user.pay_payment_processor.customer_name
  end

  test "customer with processor" do
    assert_equal @user.pay_payment_processor, @user.pay_payment_processor.api_record
  end

  test "customer with invalid processor" do
    assert_raises NameError do
      @user.set_pay_payment_processor "pants"
    end
  end

  test "customer without processor" do
    assert_raises StandardError do
      users(:none).pay_payment_processor.api_record
    end
  end

  test "subscribe" do
    assert_difference "Pay::Subscription.count" do
      @user.pay_payment_processor.subscribe
    end
  end

  test "updating a card" do
    assert @user.pay_payment_processor.update_payment_method("a1b2c3")
  end

  test "updating a card without a processor" do
    assert_raises StandardError do
      users(:none).pay_payment_processor.update_payment_method("whoops")
    end
  end

  test "subscribed? with no subscription" do
    @user.pay_payment_processor.pay_subscriptions.delete_all
    refute @user.pay_payment_processor.subscribed?
  end

  test "subscribed? with active subscription" do
    @user.pay_payment_processor.subscription.update(status: :active)
    assert @user.pay_payment_processor.subscribed?
  end

  test "subscribed? with incomplete subscription" do
    @user.pay_payment_processor.subscription.update(status: :incomplete)
    refute @user.pay_payment_processor.subscribed?
  end

  test "subscribed? with past_due subscription" do
    @user.pay_payment_processor.subscription.update(status: :past_due)
    refute @user.pay_payment_processor.subscribed?
  end

  test "subscribed? with canceled subscription" do
    @user.pay_payment_processor.subscription.update(status: :canceled, ends_at: 1.day.ago)
    refute @user.pay_payment_processor.subscribed?
  end

  test "subscribed? with canceled subscription on grace period" do
    @user.pay_payment_processor.subscription.update(status: :canceled, ends_at: 1.day.from_now)
    refute @user.pay_payment_processor.subscribed?
  end

  test "subscribed? with different plan" do
    @user.pay_payment_processor.subscription.update(processor_plan: :superior)
    refute @user.pay_payment_processor.subscribed?(processor_plan: "default")
  end

  test "subscription with active subscription" do
    subscription = @user.pay_payment_processor.pay_subscriptions.last
    assert_equal subscription, @user.pay_payment_processor.subscription
  end

  test "subscription with inactive subscription" do
    subscription = @user.pay_payment_processor.pay_subscriptions.last
    subscription.update!(ends_at: 10.days.ago)
    assert_equal subscription, @user.pay_payment_processor.subscription
  end

  test "subscription for different plan" do
    @user.pay_payment_processor.subscription.update(processor_plan: :superior)
    refute @user.pay_payment_processor.subscribed?(processor_plan: "default")
  end

  test "checking for a subscription that is active for a provided plan" do
    @user.pay_payment_processor.subscription.update(processor_plan: "other")
    assert @user.pay_payment_processor.subscribed?(name: "default", processor_plan: "other")
  end

  test "getting a subscription by default name" do
    assert_equal pay_subscriptions(:fake), @user.pay_payment_processor.subscription
  end

  test "on_trial? with no plan" do
    @user.pay_payment_processor.subscription.update(trial_ends_at: 7.days.from_now)
    assert @user.pay_payment_processor.on_trial?
  end

  test "on_trial? with plan matching the subscription plan" do
    @user.pay_payment_processor.subscription.update(trial_ends_at: 7.days.from_now)
    assert @user.pay_payment_processor.on_trial?(plan: "default")
  end

  test "on_trial? with plan different than the subscription plan" do
    @user.pay_payment_processor.subscription.update(trial_ends_at: 7.days.from_now, processor_plan: "PROCESSOR_PLAN")
    refute @user.pay_payment_processor.on_trial?(plan: "OTHERPLAN")
  end

  test "on_trial_or_subscribed? with no plan" do
    @user.pay_payment_processor.subscription.update(trial_ends_at: 7.days.from_now)
    assert @user.pay_payment_processor.on_trial_or_subscribed?
  end

  test "on_trial_or_subscribed? with a subscription that is active for another plan" do
    @user.pay_payment_processor.subscription.update(processor_plan: "superior")
    refute @user.pay_payment_processor.on_trial_or_subscribed?(name: "default", processor_plan: "default")
  end

  test "on_trial_or_subscribed? with a subscription that is active for a provided plan" do
    assert @user.pay_payment_processor.on_trial_or_subscribed?(name: "default", processor_plan: "default")
  end

  test "switching payment processor clears processor id" do
    @user.set_pay_payment_processor :stripe, processor_id: "1"
    assert_equal "1", @user.pay_payment_processor.processor_id

    @user.set_pay_payment_processor :braintree
    assert_nil @user.pay_payment_processor.processor_id
  end

  test "processor" do
    user = User.new
    assert_nil user.pay_payment_processor

    assert_difference "user.pay_customers.count" do
      user.set_pay_payment_processor :stripe
      assert_equal "stripe", user.pay_payment_processor.processor
    end

    assert_difference "user.pay_customers.count" do
      user.set_pay_payment_processor :braintree
      assert_equal "braintree", user.pay_payment_processor.processor
    end

    assert_difference "user.pay_customers.count" do
      user.set_pay_payment_processor :paddle_billing
      assert_equal "paddle_billing", user.pay_payment_processor.processor
    end

    assert_difference "user.pay_customers.count" do
      user.set_pay_payment_processor :paddle_classic
      assert_equal "paddle_classic", user.pay_payment_processor.processor
    end

    assert_difference "user.pay_customers.count" do
      user.set_pay_payment_processor :fake_processor, allow_fake: true
      assert_equal "fake_processor", user.pay_payment_processor.processor
    end
  end
end
