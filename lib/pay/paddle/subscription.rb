module Pay
  module Paddle
    class Subscription
      attr_reader :pay_subscription

      delegate :active?,
        :canceled?,
        :ends_at,
        :name,
        :on_trial?,
        :owner,
        :paddle_paused_from,
        :processor_id,
        :processor_plan,
        :processor_subscription,
        :prorate,
        :prorate?,
        :quantity,
        :quantity?,
        :trial_ends_at,
        to: :pay_subscription

      def initialize(pay_subscription)
        @pay_subscription = pay_subscription
      end

      def subscription(**options)
        hash = PaddlePay::Subscription::User.list({subscription_id: processor_id}, options).try(:first)
        OpenStruct.new(hash)
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def cancel
        subscription = processor_subscription
        PaddlePay::Subscription::User.cancel(processor_id)
        if on_trial?
          pay_subscription.update(status: :canceled, ends_at: trial_ends_at)
        else
          pay_subscription.update(status: :canceled, ends_at: Time.zone.parse(subscription.next_payment[:date]))
        end
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def cancel_now!
        PaddlePay::Subscription::User.cancel(processor_id)
        pay_subscription.update(status: :canceled, ends_at: Time.zone.now)
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def on_grace_period?
        canceled? && Time.zone.now < ends_at || paused? && Time.zone.now < paddle_paused_from
      end

      def paused?
        paddle_paused_from.present?
      end

      def pause
        attributes = {pause: true}
        response = PaddlePay::Subscription::User.update(processor_id, attributes)
        pay_subscription.update(paddle_paused_from: Time.zone.parse(response[:next_payment][:date]))
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def resume
        unless paused?
          raise StandardError, "You can only resume paused subscriptions."
        end

        attributes = {pause: false}
        PaddlePay::Subscription::User.update(processor_id, attributes)
        pay_subscription.update(status: :active, paddle_paused_from: nil)
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end

      def swap(plan)
        raise ArgumentError, "plan must be a string" unless plan.is_a?(String)

        attributes = {plan_id: plan, prorate: prorate}
        attributes[:quantity] = quantity if quantity?
        PaddlePay::Subscription::User.update(processor_id, attributes)
      rescue ::PaddlePay::PaddlePayError => e
        raise Pay::Paddle::Error, e
      end
    end
  end
end
