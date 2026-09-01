# Using Pay with Square

Square works differently from the other processors in one important way: it is a
**marketplace** processor. Instead of one platform API key, Square issues a **distinct
OAuth access token per merchant**, and you charge on behalf of each merchant's own
connected Square account (you are not the merchant of record).

Because of that, Pay does not hold a global Square key. You give Pay a resolver that
returns a fresh access token for a given customer's merchant, and Pay builds a
`Square::Client` per operation.

This processor covers **card payments, card-on-file, and refunds**. It does not implement
Square subscriptions, catalog, payouts, or the OAuth authorize/callback flow — those stay
in your app.

## Configuring the access token resolver

Set a callable that returns a fresh Square OAuth access token for a `Pay::Customer`. It
receives `(pay_customer, force_refresh = false)`; when `force_refresh` is true (after a
`401`), return a freshly refreshed token.

```ruby
# config/initializers/pay.rb
Pay::Square.access_token_provider = ->(pay_customer, force_refresh = false) do
  account = ConnectedAccount.find_by!(owner: pay_customer.owner, provider: "square")
  account.refresh! if force_refresh
  account.access_token
end
```

Your app owns storing and refreshing the token (Square access tokens expire ~30 days).
See [Credentials](2_credentials.md) for environment and webhook configuration.

## Creating customers

Tell Pay to use Square, passing the merchant id as `square_account` so the customer is
scoped to that merchant:

```ruby
@user.set_payment_processor :square, square_account: "MLXXXXXXXXXXXX"
```

`square_account` is part of the customer lookup key, so the same user transacting with two
different Square merchants gets two isolated `Pay::Customer` records. Customers are lazily
created; you can force it with `@user.payment_processor.api_record`.

## Payment methods (card-on-file)

Card capture happens client-side in Square's Web Payments SDK, which mints a single-use
`source_id` (nonce). Pass that nonce to attach a card on file:

```ruby
@user.payment_processor.add_payment_method("cnon:card-nonce-from-web-payments-sdk", default: true)
```

The app never handles raw card data (PCI SAQ A); Pay stores only Square's card token and
display metadata (`brand`, `last4`, `exp_month`, `exp_year`). The access token is never
persisted or logged.

## Charges

```ruby
# Charge the default card on file
@user.payment_processor.charge(10_00)

# Or a specific nonce, with an application fee and an app-supplied idempotency key
@user.payment_processor.charge(
  10_00,
  source_id: "cnon:...",
  currency: "usd",
  application_fee_amount: 1_00,
  idempotency_key: "appointment-42"
)
```

Square requires an idempotency key. If you pass `idempotency_key:`, resubmits of the same
logical payment (a double-clicked button, a retried request) dedupe. If you omit it, Pay
generates one that is safe within a single call and its automatic `401` retry, but not
across separate requests — pass a stable key derived from your order/appointment to be
safe.

The Square `payment_id`, `order_id`, and status are available on the charge:

```ruby
charge = @user.payment_processor.charge(10_00, source_id: "cnon:...")
charge.processor_id      # Square payment id
charge.square_order_id
charge.square_status
charge.application_fee_amount
```

## Refunds

```ruby
charge.refund!              # full
charge.refund!(5_00)        # partial
```

Square refunds are asynchronous (`PENDING` → `COMPLETED`, and can fail), so `amount_refunded`
is synced from Square's authoritative state rather than incremented optimistically; the
`refund.updated` webhook updates it again when the refund settles.

## No server-side SCA/strong-customer-authentication step

Unlike Stripe, Square has no server-side PaymentIntent/`requires_action` flow — 3-D Secure
buyer verification happens client-side in the Web Payments SDK before you receive a nonce.
So `Pay::Payment`, `Pay::Customer#has_incomplete_payment?`, and the
`payment_action_required` email do not apply to Square. A Square charge either succeeds or
raises `Pay::Square::Error`.
