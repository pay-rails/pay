module Pay
  class UserMailer < ApplicationMailer
    def receipt(user, charge)
      @user, @charge = user, charge

      if charge.respond_to? :receipt
        attachments[charge.filename] = charge.receipt
      end

      mail(
        to: to(user),
        subject: Pay.email_receipt_subject,
      )
    end

    def refund(user, charge)
      @user, @charge = user, charge

      mail(
        to: to(user),
        subject: Pay.email_refund_subject,
      )
    end

    def subscription_renewing(user, subscription)
      @user, @subscription = user, subscription

      mail(
        to: to(user),
        subject: Pay.email_renewing_subject,
      )
    end

    def payment_action_required(user, payment_intent_id, subscription)
      payment = Payment.from_id(payment_intent_id)
      @user, @payment, @subscription = user, payment, subscription

      mail(
        to: to(user),
        subject: Pay.payment_action_required_subject
      )
    end

    private

    def to(user)
      if user.respond_to?(:name)
        "#{user.name} <#{user.email}>"
      else
        user.email
      end
    end
  end
end
