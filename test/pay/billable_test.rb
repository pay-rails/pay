require 'test_helper'

class Pay::Billable::Test < DbTest
  test 'truth' do
    assert_kind_of Module, Pay::Billable
  end

  test 'has subscriptions' do
    assert @billable.respond_to?(:subscriptions)
  end

  test 'can create a subscription' do
    @billable.processor = "stripe"
    @billable.plan = "test-monthly"
    @billable.card_token = @stripe_helper.generate_card_token(brand: "Visa", last4: "9191", exp_year: 1984)
    @billable.create_subscription

    assert @billable.subscribed?
    assert @billable.subscription.name == "default"
    assert @billable.subscription.processor_plan == "test-monthly"
  end

  test 'can update his card' do
    @billable.processor = "stripe"
    @billable.update_card @stripe_helper.generate_card_token(brand: "Visa", last4: '4242')

    assert @billable.card_brand == 'Visa'
    assert @billable.card_last4 == '4242'

    @billable.update_card @stripe_helper.generate_card_token(brand: "Discover", last4: '1117')

    assert @billable.card_brand == 'Discover'
    assert @billable.card_last4 == '1117'
  end
end
