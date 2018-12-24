module Pay
  class UserMailer < ApplicationMailer
    def receipt(user, charge)
      @user, @charge = user, charge

      attachments[charge.filename] = charge.receipt.render
      mail(
        to: "#{user.name} <#{user.email}>",
        subject: "Payment receipt"
      )
    end

    def refund(user, charge)
      @user, @charge = user, charge

      mail(
        to: "#{user.name} <#{user.email}>",
        subject: "Payment refunded",
      )
    end

    def subscription_renewing(user, subscription)
      mail(
        to: "#{user.name} <#{user.email}>",
        subject: "Your upcoming subscription renewal",
      )
    end
  end
end
