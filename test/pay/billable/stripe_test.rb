require 'test_helper'
require 'stripe_mock'
require 'minitest/mock'

class Pay::Stripe::Billable::Test < ActiveSupport::TestCase
  setup do
    StripeMock.start

    @billable = User.new email: 'johnny@appleseed.com'
    @billable.processor = 'stripe'

    @stripe_helper = StripeMock.create_test_helper
    @stripe_helper.create_plan(id: 'test-monthly', amount: 1500)
  end

  teardown do
    StripeMock.stop
  end

  test 'getting a stripe customer with a processor id' do
    customer = Stripe::Customer.create(
      email: 'johnny@appleseed.com',
      card: @stripe_helper.generate_card_token
    )

    @billable.processor_id = customer.id

    assert_equal @billable.stripe_customer, customer
  end

  test 'getting a stripe customer without a processor id' do
    assert_nil @billable.processor_id

    @billable.card_token = @stripe_helper.generate_card_token(
      brand: 'Visa',
      last4: '9191',
      exp_year: 1984
    )

    @billable.stripe_customer

    assert_not_nil @billable.processor_id

    assert @billable.card_type == 'Visa'
    assert @billable.card_last4 == '9191'
  end

  test 'can create a charge' do
    @billable.card_token = @stripe_helper.generate_card_token(
      brand: 'Visa',
      last4: '9191',
      exp_year: 1984
    )

    charge = @billable.charge(2900)
    assert_equal Pay::Charge, charge.class
    assert_equal 2900, charge.amount
  end

  test 'can create a subscription' do
    @billable.card_token = @stripe_helper.generate_card_token(
      brand: 'Visa',
      last4: '9191',
      exp_year: 1984
    )
    @billable.subscribe(name: 'default', plan: 'test-monthly')

    assert @billable.subscribed?
    assert_equal 'default', @billable.subscription.name
    assert_equal 'test-monthly', @billable.subscription.processor_plan
  end

  test 'can update their card' do
    customer = Stripe::Customer.create(
      email: 'johnny@appleseed.com',
      card: @stripe_helper.generate_card_token
    )

    @billable.stubs(:customer).returns(customer)
    card = @stripe_helper.generate_card_token(brand: 'Visa', last4: '4242')
    @billable.update_card(card)

    assert_equal 'Visa', @billable.card_type
    assert_equal '4242', @billable.card_last4
    assert_nil @billable.card_token

    card = @stripe_helper.generate_card_token(
      brand: 'Discover',
      last4: '1117'
    )
    @billable.update_card(card)

    assert @billable.card_type == 'Discover'
    assert @billable.card_last4 == '1117'
  end

  test 'retriving a stripe subscription' do
    @stripe_helper.create_plan(id: 'default', amount: 1500)

    customer = Stripe::Customer.create(
      email: 'johnny@appleseed.com',
      source: @stripe_helper.generate_card_token(brand: 'Visa', last4: '4242')
    )

    subscription = Stripe::Subscription.create(
      plan: 'default',
      customer: customer.id
    )

    assert_equal @billable.stripe_subscription(subscription.id), subscription
  end

  test 'can create an invoice' do
    customer = Stripe::Customer.create(
      email: 'johnny@appleseed.com',
      card: @stripe_helper.generate_card_token
    )
    @billable.stubs(:customer).returns(customer)
    @billable.processor = 'stripe'
    @billable.processor_id = customer.id

    Stripe::InvoiceItem.create(
      customer: customer.id,
      amount: 1000,
      currency: 'usd',
      description: 'One-time setup fee'
    )

    assert_equal 1000, @billable.invoice!.total
  end

  test 'card gets updated automatically when retrieving customer' do
    customer = Stripe::Customer.create(
      email: @billable.email,
      card: @stripe_helper.generate_card_token
    )

    @billable.processor = 'stripe'
    @billable.processor_id = customer.id

    assert_equal @billable.customer, customer

    @billable.card_token = @stripe_helper.generate_card_token(
      brand: 'Discover',
      last4: '1117'
    )

    # This should trigger update_card
    assert_equal @billable.customer, customer
    assert_equal @billable.card_type, 'Discover'
    assert_equal @billable.card_last4, '1117'
  end

  test 'creating a stripe customer with no card' do
    @billable.customer

    assert_nil @billable.card_last4
    assert_equal @billable.processor, 'stripe'
    assert_not_nil @billable.processor_id
  end

  test 'email changed' do
    # Must already have a processor ID
    @billable.customer # Sets customer ID

    Pay::EmailSyncJob.expects(:perform_later).with(@billable.id)
    @billable.update(email: "mynewemail@example.org")
  end

  test 'handles exception when creating a customer' do
    custom_error = StandardError.new("Oops")
    StripeMock.prepare_error(custom_error, :new_customer)

    exception = assert_raises(Pay::Error) { @billable.stripe_customer }
    assert_equal( "Oops", exception.message )
  end

  test 'handles exception when creating a charge' do
    custom_error = StandardError.new("Oops")
    StripeMock.prepare_error(custom_error, :new_charge)

    exception = assert_raises(Pay::Error) { @billable.charge(1000) }
    assert_equal( "Oops", exception.message )
  end

  test 'handles exception when creating a subscription' do
    custom_error = StandardError.new("Oops")
    StripeMock.prepare_error(custom_error, :create_customer_subscription)

    @billable.card_token = @stripe_helper.generate_card_token(
      brand: 'Visa',
      last4: '9191',
      exp_year: 1984
    )

    exception = assert_raises(Pay::Error) { @billable.subscribe plan: 'test-monthly' }
    assert_equal( "Oops", exception.message )
  end

  test 'handles exception when updating a card' do
    custom_error = StandardError.new("Oops")
    StripeMock.prepare_error(custom_error, :create_source)

    card_token = @stripe_helper.generate_card_token(
      brand: 'Visa',
      last4: '9191',
      exp_year: 1984
    )

    exception = assert_raises(Pay::Error) { @billable.update_card(card_token) }
    assert_equal( "Oops", exception.message )
  end
end
