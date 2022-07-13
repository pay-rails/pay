module Pay
  class UserMailer < Pay.parent_mailer.constantize
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
      Mail::Address.new.tap do |builder|
        builder.address = params[:pay_customer].email
        builder.display_name = params[:pay_customer].customer_name
      end.to_s
    end
  end
end
