module Pay
  class Webhook < Pay::ApplicationRecord
    validates :processor, presence: true
    validates :event_type, presence: true
    validates :event, presence: true

    def process!
      Pay::Webhooks.instrument type: "#{processor}.#{event_type}", event: rehydrated_event

      # Remove after successfully processing
      destroy
    end

    # Events have already been verified by the webhook, so we just store the raw data
    # Then we can rehydrate as webhook objects for each payment processor
    def rehydrated_event
      case processor
      when "braintree"
        Pay.braintree_gateway.webhook_notification.parse(event["bt_signature"], event["bt_payload"])
      when "paddle"
        to_recursive_ostruct(event)
      when "stripe"
        ::Stripe::Event.construct_from(event)
      else
        event
      end
    end

    def to_recursive_ostruct(hash)
      result = hash.each_with_object({}) do |(key, val), memo|
        memo[key] = val.is_a?(Hash) ? to_recursive_ostruct(val) : val
      end
      OpenStruct.new(result)
    end
  end
end
