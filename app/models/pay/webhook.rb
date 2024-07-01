module Pay
  class Webhook < Pay::ApplicationRecord
    validates :processor, presence: true
    validates :event_type, presence: true
    validates :event, presence: true

    def process!
      Pay::Webhooks.instrument type: "#{processor}.#{event_type}", event: rehydrated_event

      # Remove after successfully processing
      # destroy
    end

    # Events have already been verified by the webhook, so we just store the raw data
    # Then we can rehydrate as webhook objects for each payment processor
    def rehydrated_event
      case processor
      when "braintree"
        Pay.braintree_gateway.webhook_notification.parse(event["bt_signature"], event["bt_payload"])
      when "paddle_billing"
        to_recursive_ostruct(event["data"])
      when "paddle_classic"
        to_recursive_ostruct(event)
      when "lemon_squeezy"
        to_recursive_ostruct(event)
      when "stripe"
        ::Stripe::Event.construct_from(event)
      else
        event
      end
    end

    def to_recursive_ostruct(obj)
      if obj.is_a?(Hash)
        OpenStruct.new(obj.map { |key, val| [key, to_recursive_ostruct(val)] }.to_h)
      elsif obj.is_a?(Array)
        obj.map { |o| to_recursive_ostruct(o) }
      else # Assumed to be a primitive value
        obj
      end
    end
  end
end
