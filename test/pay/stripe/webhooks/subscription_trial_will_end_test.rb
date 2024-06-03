require "test_helper"

class Pay::Stripe::Webhooks::SubscriptionTrialWillEndTest < ActiveSupport::TestCase
  setup do
    @trial_will_end_event = stripe_event("subscription.trial_will_end")
    @trial_ended_event = stripe_event("subscription.trial_ended")
    @pay_customer = pay_customers(:stripe)
    @pay_customer.update(processor_id: @trial_will_end_event.data.object.customer)
  end

  test "trial subscription ending soon customer should receive trial will end email if setting is enabled" do
    Pay.emails.subscription_trial_will_end = true # Default is true, setting here for clarity
    ::Stripe::Subscription.expects(:retrieve).returns(@trial_will_end_event.data.object)

    travel_to trial_start_date do
      create_subscription(processor_id: @trial_will_end_event.data.object.items.data.first.subscription, trial_ends_at: 3.days.from_now)
      mailer = Pay::Stripe::Webhooks::SubscriptionTrialWillEnd.new.call(@trial_will_end_event)

      assert mailer.arguments.include?("subscription_trial_will_end")
      assert_enqueued_emails 1
    end
  end

  test "trial subscription ending soon customer should not receive trial will end email if setting is disabled" do
    Pay.emails.subscription_trial_will_end = false
    ::Stripe::Subscription.expects(:retrieve).returns(@trial_will_end_event.data.object)

    travel_to trial_start_date do
      create_subscription(processor_id: @trial_will_end_event.data.object.items.data.first.subscription, trial_ends_at: 3.days.from_now)
      Pay::Stripe::Webhooks::SubscriptionTrialWillEnd.new.call(@trial_will_end_event)

      assert_enqueued_emails 0
    end
  end

  test "trial subscription ended immediately customer should receive trial ended email if setting is enabled" do
    Pay.emails.subscription_trial_ended = true # Default is true, setting here for clarity
    ::Stripe::Subscription.expects(:retrieve).returns(@trial_ended_event.data.object)

    create_subscription(processor_id: @trial_ended_event.data.object.items.data.first.subscription, trial_ends_at: Time.current)
    mailer = Pay::Stripe::Webhooks::SubscriptionTrialWillEnd.new.call(@trial_ended_event)

    assert mailer.arguments.include?("subscription_trial_ended")
    assert_enqueued_emails 1
  end

  test "trial subscription ended immediately customer should not receive trial ended email if setting is disabled" do
    Pay.emails.subscription_trial_ended = false
    ::Stripe::Subscription.expects(:retrieve).returns(@trial_ended_event.data.object)

    create_subscription(processor_id: @trial_ended_event.data.object.items.data.first.subscription, trial_ends_at: Time.current)
    Pay::Stripe::Webhooks::SubscriptionTrialWillEnd.new.call(@trial_ended_event)

    assert_enqueued_emails 0
  end

  test "sync! is called with stripe_account" do
    event = @trial_ended_event.clone
    event.account = "connect_account_id"

    pay_subscription = Pay::Subscription.new
    Pay::Subscription.stubs(:find_by_processor_and_id).returns(pay_subscription)
    pay_subscription.expects(:sync!).with(stripe_account: "connect_account_id")

    Pay::Stripe::Webhooks::SubscriptionTrialWillEnd.new.call(event)
  end

  private

  def create_subscription(processor_id:, trial_ends_at:)
    @pay_customer.subscriptions.create!(processor_id: processor_id, name: "default", processor_plan: "some-plan", status: "active", trial_ends_at: trial_ends_at)
  end

  def trial_start_date
    Time.at(@trial_will_end_event.data.object.trial_start)
  end
end
