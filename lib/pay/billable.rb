module Pay
  module Billable
    def customer
      raise Pay::Error, I18n.t("errors.email_required") if email.nil?

      customer = payment_processor.customer
      payment_processor.update_card(card_token) if card_token.present?
      customer
    end

    def on_generic_trial?
      trial_ends_at? && trial_ends_at > Time.zone.now
    end

    def processor_subscription(subscription_id, options = {})
      payment_processor.processor_subscription(subscription_id, options)
    end


    # Used for creating a Pay::Subscription in the database
    def create_pay_subscription(subscription, processor, name, plan, options = {})
      options[:quantity] ||= 1

      options.merge!(
        name: name || "default",
        processor: processor,
        processor_id: subscription.id,
        processor_plan: plan,
        trial_ends_at: payment_processor.trial_end_date(subscription),
        ends_at: nil
      )
      subscriptions.create!(options)
    end

    private

    def default_generic_trial?(name, plan)
      # Generic trials don't have plans or custom names
      plan.nil? && name == "default" && on_generic_trial?
    end

    def pay_fake_processor_is_allowed
      return unless processor == "fake_processor"
      errors.add(:processor, "must be a valid payment processor") unless pay_fake_processor_allowed?
    end
  end
end
