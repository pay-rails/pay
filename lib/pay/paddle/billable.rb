module Pay
  module Paddle
    module Billable
      extend ActiveSupport::Concern

      included do
        scope :paddle, -> { where(processor: :paddle) }
      end

      def paddle_customer
        # pass
      end

      def create_paddle_charge(amount, options = {})
        return unless subscription.processor_id
        raise Pay::Error, "A charge_name is required to create a one-time charge" if options[:charge_name].nil?
        response = PaddlePay::Subscription::Charge.create(subscription.processor_id, amount.to_f / 100, options[:charge_name], options)
        charge = charges.find_or_initialize_by(
          processor: :paddle,
          processor_id: response[:invoice_id]
        )
        charge.update(
          amount: Integer(response[:amount].to_f * 100),
          card_type: subscription.processor_subscription.payment_information[:payment_method],
          paddle_receipt_url: response[:receipt_url],
          created_at: DateTime.parse(response[:payment_date])
        )
        charge
      rescue ::PaddlePay::PaddlePayError => e
        raise Error, e.message
      end

      def create_paddle_subscription(name, plan, options = {})
        # pass
      end

      def update_paddle_card(token)
        # pass
      end

      def update_paddle_email!
        # pass
      end

      def paddle_trial_end_date(subscription)
        return unless subscription.state == "trialing"
        DateTime.parse(subscription.next_payment[:date]).end_of_day
      end

      def paddle_subscription(subscription_id, options = {})
        hash = PaddlePay::Subscription::User.list({subscription_id: subscription_id}, options).try(:first)
        OpenStruct.new(hash)
      rescue ::PaddlePay::PaddlePayError => e
        raise Error, e.message
      end

      def paddle_invoice!(options = {})
        # pass
      end

      def paddle_upcoming_invoice
        # pass
      end
    end
  end
end
