module Pay
  class UserMailer < ApplicationMailer
    def receipt(user, charge)
      @user, @charge = user, charge

      attachments[charge.filename] = charge.receipt.render
      mail(
        to: to(user),
        subject: "Payment receipt",
      )
    end

    def refund(user, charge)
      @user, @charge = user, charge

      mail(
        to: to(user),
        subject: "Payment refunded",
      )
    end

    def subscription_renewing(user, subscription)
      mail(
        to: to(user),
        subject: "Your upcoming subscription renewal",
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
