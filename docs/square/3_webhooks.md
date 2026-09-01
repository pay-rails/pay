# Square Webhooks

Pay mounts a Square webhook endpoint at `/pay/webhooks/square` (like the other
processors). Point your Square webhook subscription at it and set the signing secret and
notification URL (see [Credentials](2_credentials.md)).

Requests are verified with Square's `x-square-hmacsha256-signature` header (HMAC-SHA256 over
`notification_url + raw body`, base64) before anything is processed. Invalid signatures get
a `400`.

## Handled events

Pay handles the payment/refund/card/customer events for this slice:

* `payment.created`, `payment.updated`
* `refund.created`, `refund.updated`
* `card.created`, `card.updated`, `card.disabled`
* `customer.created`, `customer.updated`, `customer.deleted`

Payout events are intentionally not handled here — settlement/reconciliation is app-side.

## Ordering and idempotency

Square webhook delivery is unordered and at-least-once. Rather than trusting the snapshot in
the payload (which could be stale relative to a later event), the handlers take the object
id from the verified event and **re-fetch authoritative state** from the Square API via the
merchant's token, then upsert. This makes duplicate and out-of-order deliveries safe.

## Subscribing your own handlers

Pay uses `ActiveSupport::Notifications` under the hood. Subscribe to any event with the
`square.` prefix:

```ruby
Pay::Webhooks.configure do |events|
  events.subscribe "square.payment.updated" do |event|
    # ...
  end
end
```
