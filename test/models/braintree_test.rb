require 'test_helper'

class Pay::Subscription::BraintreeTest < ActiveSupport::TestCase
  setup do
    @billable = User.new email: "test@example.com"
    @billable.processor = 'braintree'
    @billable.card_token = 'fake-valid-visa-nonce'
  end

  test 'cancel' do
    VCR.use_cassette('braintree-cancel') do
      @billable.subscribe(trial_duration: 0)
      @subscription = @billable.subscription
      @subscription.cancel
      assert_equal @subscription.ends_at, @subscription.processor_subscription.billing_period_end_date
    end
  end

  test 'cancel_now!' do
    VCR.use_cassette('braintree-cancel-now') do
      @billable.subscribe(trial_duration: 0)
      @subscription = @billable.subscription
      @subscription.cancel_now!
      assert @subscription.ends_at <= Time.zone.now
    end
  end

  test 'resume on grace period' do
    VCR.use_cassette('braintree-resume') do
      travel_to(VCR.current_cassette.originally_recorded_at || Time.current) do
        @billable.subscribe(trial_duration: 14)
        @subscription = @billable.subscription
        @subscription.cancel
        assert_equal @subscription.ends_at, @subscription.trial_ends_at

        @subscription.resume
        assert_nil @subscription.ends_at
      end
    end
  end

  test 'processor subscription' do
    VCR.use_cassette('braintree-processor-subscription') do
      @billable.subscribe(trial_duration: 0)
      assert_equal @billable.subscription.processor_subscription.class, Braintree::Subscription
    end
  end

  test 'can swap plans' do
    VCR.use_cassette('braintree-swap-plan') do
      @billable.subscribe(plan: 'default', trial_duration: 0)
      @billable.subscription.swap('big')

      assert_equal 'big', @billable.subscription.processor_subscription.plan_id
    end
  end

  test 'can swap plans between frequencies' do
    VCR.use_cassette('braintree-swap-plan-frequency') do
      @billable.subscribe(plan: 'default', trial_duration: 0)
      @billable.subscription.swap('yearly')

      assert_equal 'yearly', @billable.subscription.processor_subscription.plan_id
    end
  end
end
