module Pay
  class UserMailer < Pay.parent_mailer
    def receipt
      if params[:pay_charge].respond_to? :receipt
        attachments[params[:pay_charge].filename] = params[:pay_charge].receipt
      end

      mail to: to
    end

    def refund
      mail to: to
    end

    def subscription_renewing
      mail to: to
    end

    def payment_action_required
      mail to: to
    end

    private

    def to
      "#{params[:pay_customer].customer_name} <#{params[:pay_customer].email}>"
    end
  end
end
