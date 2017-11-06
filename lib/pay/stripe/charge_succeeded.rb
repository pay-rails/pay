module Pay
  module Stripe
    class ChargeSucceeded
      def call(event)
        object = event.data.object
        user   = User.find_by(
          processor: :stripe,
          processor_id: object.customer
        )

        return unless user.present?
        return if user.charges.where(processor_id: object.id).any?

        charge = create_charge(user, object)
        notify_user(charge)
      end

      def create_charge(user, object)
        user.charges.create(
          processor:      :stripe,
          processor_id:   object.id,
          amount:         object.amount,
          card_last4:     object.source.last4,
          card_type:      object.source.brand,
          card_exp_month: object.source.exp_month,
          card_exp_year:  object.source.exp_year,
          created_at:     Time.zone.at(object.created)
        )
      end

      def notify_user(charge)
        # Pay::UserMailer.receipt(charge).deliver_later
      end
    end
  end
end
