require 'test_helper'
require 'stripe_mock'
require 'minitest/mock'

class Pay::Billable::Test < ActiveSupport::TestCase
  setup do
    StripeMock.start

    @billable = User.new
    @stripe_helper = StripeMock.create_test_helper
    @stripe_helper.create_plan(id: 'test-monthly', amount: 1500)
  end

  teardown do
    StripeMock.stop
  end

  test 'truth' do
    assert_kind_of Module, Pay::Billable
  end

  test 'has subscriptions' do
    assert @billable.respond_to?(:subscriptions)
  end

  test 'can create a subscription' do
    @billable.card_token = @stripe_helper.generate_card_token(
      brand: 'Visa',
      last4: '9191',
      exp_year: 1984
    )
    @billable.subscribe('default', 'test-monthly')

    assert @billable.subscribed?
    assert @billable.subscription.name == 'default'
    assert @billable.subscription.processor_plan == 'test-monthly'
  end

  test 'can update their card' do
    customer = Stripe::Customer.create(
      email: 'johnny@appleseed.com',
      card: @stripe_helper.generate_card_token
    )

    @billable.stub :processor_customer, customer do
      card = @stripe_helper.generate_card_token(brand: 'Visa', last4: '4242')
      @billable.update_card(card)

      assert @billable.card_brand == 'Visa'
      assert @billable.card_last4 == '4242'

      card = @stripe_helper.generate_card_token(brand: 'Discover', last4: '1117')
      @billable.update_card(card)

      assert @billable.card_brand == 'Discover'
      assert @billable.card_last4 == '1117'
    end
  end
end
