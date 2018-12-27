module Pay
  class UserMailer < ApplicationMailer
    def receipt(user, charge)
      @user, @charge = user, charge

      attachments[charge.filename] = charge.receipt if charge.respond_to? :receipt

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
      mail(
        to: to(user),
        subject: Pay.email_renewing_subject,
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
