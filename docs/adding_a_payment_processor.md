# Adding a Payment Processor to Pay

Each payment processor has different needs for webhooks. Rather than relying on external gems,
Pay handles webhooks internally.

## Webhook Controller

Each payment processer can define it's own controller for processing any required webhooks.

For example, `stripe` has [app/controllers/pay/webhooks/stripe_controller.rb](../app/controllers/pay/webhooks/stripe_controller.rb)

See also [config/routes.rb](../config/routes.rb) for defining routes.

The webhook controller is responsible for verifying the webhook payload for authenticity and then sending to the Pay Webhook Delegator

### Pay Webhook Delegator

The Webhook Delegator is responsible for taking an event type and sending it for processing.

It uses [ActiveSupport::Notifications](https://api.rubyonrails.org/classes/ActiveSupport/Notifications.html) to subscribe and instrument events.

```ruby
Pay::Webhooks.configure do |events|
  events.subscribe "stripe.charge.succeeded", Pay::Stripe::Webhooks::ChargeSucceeded.new
end

module Pay
  module Stripe
    module Webhooks
      class ChargeSucceeded
        def call(event)
          # processing goes here
        end
      end
    end
  end
end
```

For example, when a `stripe.charge.succeeded` event gets processed, the webhook delegator sends the event to any classes that are subscribed to the event type.

Internally, these events are automatically prefaced with the `pay` namespace so they don't conflict with other events. `stripe.charge.succeeded` is internally routed as `pay.stripe.charge.succeeded`. Payment processors should _not_ preface with `pay.` as it is automatically added.
