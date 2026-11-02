module Pay
  class UserMailer < Pay.parent_mailer.constantize
    def receipt
      pay_charge = params[:pay_charge]

      if pay_charge.respond_to? :receipt
        attachments[pay_charge.receipt_filename] = pay_charge.receipt
        attachments[pay_charge.invoice_filename] = pay_charge.invoice if Pay.resolve_option(Pay.attach_invoice_to_receipt, pay_charge)
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

    def payment_failed
      mail mail_arguments
    end

    private

    def mail_arguments
      instance_exec(&Pay.mail_arguments)
    end
  end
end
