module Pay
  module Paddle
    module Subscription
      extend ActiveSupport::Concern

      included do
        scope :paddle, -> { where(processor: :paddle) }

        store_accessor :data, :paddle_update_url
        store_accessor :data, :paddle_cancel_url
      end

      def paddle?
        processor == "paddle"
      end

      def paddle_cancel
        subscription = processor_subscription
        PaddlePay::Subscription::User.cancel(processor_id)
        if on_trial?
          update(status: :canceled, ends_at: trial_ends_at)
        else
          update(status: :canceled, ends_at: Time.zone.parse(subscription.next_payment[:date]))
        end
      rescue ::PaddlePay::PaddlePayError => e
        raise Error, e.message
      end

      def paddle_cancel_now!
        PaddlePay::Subscription::User.cancel(processor_id)
        update(status: :canceled, ends_at: Time.zone.now)
      rescue ::PaddlePay::PaddlePayError => e
        raise Error, e.message
      end

      def paddle_pause
        attributes = {pause: true}
        response = PaddlePay::Subscription::User.update(processor_id, attributes)
        update(paused_from: Time.zone.parse(response[:next_payment][:date]))
      rescue ::PaddlePay::PaddlePayError => e
        raise Error, e.message
      end

      def paddle_resume
        attributes = {pause: false}
        PaddlePay::Subscription::User.update(processor_id, attributes)
        update(status: :active, paused_from: nil)
      rescue ::PaddlePay::PaddlePayError => e
        raise Error, e.message
      end

      def paddle_swap(plan)
        attributes = {plan_id: plan, prorate: prorate}
        attributes[:quantity] = quantity if quantity?
        PaddlePay::Subscription::User.update(processor_id, attributes)
      rescue ::PaddlePay::PaddlePayError => e
        raise Error, e.message
      end
    end
  end
end
