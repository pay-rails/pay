module Pay
  class UserMailer < Pay.parent_mailer.constantize
    def receipt
      if params[:pay_charge].respond_to? :receipt
        attachments[params[:pay_charge].filename] = params[:pay_charge].receipt
      end

      mail mail_arguments
    end

    def refund
      mail mail_arguments
    end

    def subscription_renewing
      mail mail_arguments
    end

    def payment_action_required
      mail mail_arguments
    end

    def subscription_trial_will_end
      mail mail_arguments
    end

    def subscription_trial_ended
      mail mail_arguments
    end

    private

    def mail_arguments
      instance_exec(&Pay.mail_arguments)
    end
  end
end
