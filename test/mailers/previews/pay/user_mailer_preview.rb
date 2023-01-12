class Pay::UserMailerPreview < ActionMailer::Preview
  def payment_action_required
    Pay::UserMailer.with(
      pay_customer: Pay::Customer.first,
      payment_intent_id: "fake"
    ).payment_action_required
  end

  def payment_failed
    Pay::UserMailer.with(
      pay_customer: Pay::Customer.first
    ).payment_failed
  end

  def receipt
    Pay::UserMailer.with(
      pay_customer: Pay::Customer.first,
      pay_charge: Pay::Charge.first
    ).receipt
  end

  def refund
    Pay::UserMailer.with(
      pay_customer: Pay::Customer.first,
      pay_charge: Pay::Charge.first
    ).receipt
  end

  def subscription_renewing
    Pay::UserMailer.with(
      pay_customer: Pay::Customer.first,
      pay_subscription: Pay::Subscription.first,
      date: Date.today
    ).subscription_renewing
  end

  def subscription_trial_ended
    Pay::UserMailer.with(
      pay_customer: Pay::Customer.first,
      pay_subscription: Pay::Subscription.first
    ).subscription_trial_ended
  end

  def subscription_trial_will_end
    Pay::UserMailer.with(
      pay_customer: Pay::Customer.first,
      pay_subscription: Pay::Subscription.first
    ).subscription_trial_will_end
  end
end
