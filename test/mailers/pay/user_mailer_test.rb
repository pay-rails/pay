require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  setup do
    @charge = pay_charges(:stripe)
    @pay_customer = @charge.customer
    @user = @pay_customer.owner
    @user.update(extra_billing_info: 'extra billing info')

    @charge.update stripe_invoice: JSON.parse(file_fixture('stripe/invoice.json').read)
  end

  test 'from address with Pay.support_email' do
    Pay.stub :support_email, 'pay@test.org' do
      assert_equal 'pay@test.org', Pay::ApplicationMailer.default_from_address
    end
  end

  test 'from address fallback to ::ApplicationMailer.default_params' do
    Pay.stub :support_email, nil do
      assert_equal 'from@example.com', Pay::ApplicationMailer.default_from_address
    end
  end

  test 'receipt' do
    email = Pay::UserMailer.with(pay_customer: @pay_customer, pay_charge: @charge).receipt

    assert_equal [@user.email], email.to
    assert_equal I18n.t('pay.user_mailer.receipt.subject', application: Pay.application_name), email.subject
  end

  test 'render receipt with missing support email' do
    Pay.stub :support_email, nil do
      assert_nothing_raised do
        @charge.receipt
      end
    end
  end

  test 'attaches refunds to receipt' do
    filename = 'receipt.pdf'

    receipt = mock('receipt')
    receipt.stubs(:render).returns('render content')
    receipt.stubs(:length).returns(1024)

    @charge.stubs(:filename).returns(filename)
    @charge.stubs(:receipt).returns(receipt)

    email = Pay::UserMailer.with(pay_customer: @pay_customer, pay_charge: @charge).receipt

    assert_equal filename, email.attachments.first.filename
  end

  test 'refund' do
    email = Pay::UserMailer.with(pay_customer: @pay_customer, pay_charge: @charge).refund

    assert_equal [@user.email], email.to
    assert_equal I18n.t('pay.user_mailer.refund.subject', application: Pay.application_name), email.subject
  end

  test 'subscription_renewing' do
    time = Time.current
    email = Pay::UserMailer.with(pay_customer: @pay_customer, pay_subscription: Pay::Subscription.new, date: time).subscription_renewing

    assert_equal [@user.email], email.to
    assert_equal I18n.t('pay.user_mailer.subscription_renewing.subject', application: Pay.application_name),
                 email.subject
    assert_includes email.html_part.decoded, I18n.l(time.to_date, format: :long)
  end

  test 'payment_action_required' do
    email = Pay::UserMailer.with(pay_customer: @pay_customer, payment_intent_id: 'x', pay_subscription: Pay::Subscription.new).payment_action_required

    assert_equal [@user.email], email.to
    assert_equal I18n.t('pay.user_mailer.payment_action_required.subject', application: Pay.application_name), email.subject
    assert_includes email.html_part.decoded, Pay::Engine.instance.routes.url_helpers.payment_path('x')
  end

  test 'receipt with no extra billing info column' do
    team = teams(:one)
    @pay_customer.update!(owner: team)
    email = Pay::UserMailer.with(pay_customer: @pay_customer, pay_charge: @charge).receipt

    assert_equal [team.owner.email], email.to
    assert_equal I18n.t('pay.user_mailer.receipt.subject', application: Pay.application_name), email.subject
  end

  test 'refund with no extra billing info column' do
    team = teams(:one)
    @pay_customer.update!(owner: team)
    email = Pay::UserMailer.with(pay_customer: @pay_customer, pay_charge: @charge).refund

    assert_equal [team.owner.email], email.to
    assert_equal I18n.t('pay.user_mailer.refund.subject', application: Pay.application_name), email.subject
  end

  test 'subscription_trial_will_end' do
    email = Pay::UserMailer.with(pay_customer: @pay_customer).subscription_trial_will_end

    assert_equal [@user.email], email.to
    assert_equal I18n.t('pay.user_mailer.subscription_trial_will_end.subject', application: Pay.application_name), email.subject
    assert_includes email.html_part.decoded, 'trial is ending soon'
  end

  test 'subscription_trial_ended' do
    email = Pay::UserMailer.with(pay_customer: @pay_customer).subscription_trial_ended

    assert_equal [@user.email], email.to
    assert_equal I18n.t('pay.user_mailer.subscription_trial_ended.subject', application: Pay.application_name), email.subject
    assert_includes email.html_part.decoded, 'trial has ended'
  end

  test 'subscription payment failed' do
    email = Pay::UserMailer.with(pay_customer: @pay_customer).payment_failed

    assert_equal [@user.email], email.to
    assert_equal I18n.t('pay.user_mailer.payment_failed.subject', application: Pay.application_name), email.subject
    assert_includes email.html_part.decoded, 'payment was declined'
  end
end
