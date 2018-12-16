module Pay
  class UserMailer < ApplicationMailer
    def receipt(user, charge)
      @user, @charge = user, charge

      if charge.receipt
        attachments[charge.filename] = charge.receipt.render
      end

      mail(
        to: "#{user.name} <#{user.email}>",
        from: "Payment receipt"
      )
    end

    def refund(user, charge)
      @user, @charge = user, charge

      mail(
        to: "#{user.name} <#{user.email}>",
        from: "Payment refunded",
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
