module Pay
  class UserMailer < ApplicationMailer
    def receipt
      if params[:charge].respond_to? :receipt
        attachments[params[:charge].filename] = params[:charge].receipt
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
      @payment = payment_intent
      mail to: to
    end

    private

    def to
      if params[:billable].respond_to?(:customer_name)
        "#{params[:billable].customer_name} <#{params[:billable].email}>"
      else
        params[:billable].email
      end
    end

    def payment_intent
      case params[:payment_intent_id]
      when String
        Payment.from_id(params[:payment_intent_id])
      else
        params[:payment_intent_id]
      end
    end
  end
end
