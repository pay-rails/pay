# Cryptocurrency Payments with Pay

The Pay gem supports cryptocurrency payments through multiple payment processors. Currently, **BTCPay Server** is the primary integration, enabling Bitcoin and other cryptocurrency payments.

## BTCPay Server Integration

[BTCPay Server](https://btcpayserver.org/) is a free and open-source payment processor that enables direct Bitcoin and cryptocurrency payments without intermediaries.

### Features

- **Direct cryptocurrency payments** - No middleman, no fees to payment processor
- **Multiple cryptocurrencies** - Bitcoin, Litecoin, Dogecoin, and many more
- **Self-hosted** - Run on your own server for complete control
- **Privacy-friendly** - No personal data storage or tracking
- **Lightning Network** - Instant payments with zero fees
- **Plugin ecosystem** - Integrations with many ecommerce platforms
- **Open source** - Full transparency and community-driven development

### Setup

#### 1. Create a BTCPay Server Instance

You can either:
- Self-host: https://docs.btcpayserver.org/Deployment/
- Use a hosted provider: https://mainnet.demo.btcpayserver.org/

#### 2. Configure Pay Gem

In your `config/initializers/pay.rb`:

```ruby
Pay::Btcpay.configure do |config|
  config.api_url = "https://your-btcpay-instance.com"
  config.api_key = ENV["BTCPAY_API_KEY"]
  config.store_id = ENV["BTCPAY_STORE_ID"]
end
```

Get your API key and store ID from BTCPay Server's settings.

### Creating a Cryptocurrency Customer

```ruby
# Create a Pay customer for cryptocurrency payments
pay_customer = user.payment_processor("btcpay")
```

The customer doesn't need payment information upfront - payment is requested on-demand via invoices.

## One-Time Crypto Payments (Invoices)

### Creating an Invoice

```ruby
pay_customer = user.payment_processor("btcpay")

charge = pay_customer.charge(
  10_000,  # Amount in cents ($100.00)
  currency: "USD",
  description: "Order #12345",
  order_id: "order_123",
  success_url: "https://example.com/order/success",
  redirect_url: "https://example.com/order"
)

# charge.processor_id contains the invoice ID
# charge.data contains the full invoice details from BTCPay
invoice_url = charge.data["url"]  # Share this with the customer
```

### Sharing Payment Links

BTCPay invoices are shareable via URL. You can:
- Redirect to the invoice URL: `redirect_to invoice.data["url"]`
- Generate a QR code from the payment address
- Display a Bolt-11 Lightning invoice QR code
- Embed the payment details in your application

### Receiving Payments

Payments are processed asynchronously:

```ruby
# Listen for payment webhooks
Pay.subscribe("btcpay.charge.completed") do |event|
  charge = event.charge
  # Fulfill the order
end

Pay.subscribe("btcpay.charge.failed") do |event|
  charge = event.charge
  # Invoice expired without full payment
end

Pay.subscribe("btcpay.payment_received") do |event|
  charge = event.charge
  # Payment received but may not be fully confirmed
end
```

### Invoice States

BTCPay invoices progress through these states:

1. **New** - Invoice created, awaiting payment
2. **Received** - Payment detected but not fully confirmed
3. **Settled** - Blockchain confirmations received, payment secure
4. **Expired** - Invoice expiration time passed without payment

## Recurring Crypto Payments

### Creating a Subscription

```ruby
pay_customer = user.payment_processor("btcpay")

subscription = pay_customer.subscribe(
  "bitcoin-pro",
  amount: 5_000,  # $50/month in cents
  currency: "USD",
  period: "month",
  description: "Pro Subscription",
  success_url: "https://example.com/subscriptions/success",
  expired_url: "https://example.com/subscriptions/expired"
)

payment_url = subscription.data["url"]  # Share with customer
```

### Managing Subscriptions

```ruby
subscription = user.subscriptions.find_by(processor: "btcpay")

# Pause and resume
subscription.pause
subscription.resume

# Swap to different plan
subscription.swap("bitcoin-premium", amount: 10_000)

# Cancel
subscription.cancel
subscription.cancel_now!
```

### Subscription Webhooks

```ruby
Pay.subscribe("btcpay.subscription.payment_received") do |event|
  subscription = event.subscription
  # Recurring payment received
end

Pay.subscribe("btcpay.subscription.expired") do |event|
  subscription = event.subscription
  # Subscription payment request expired
end
```

## Payment Methods

With BTCPay, payment methods represent wallet addresses or payment identifiers:

```ruby
pay_customer = user.payment_processor("btcpay")

# Add a payment method (wallet address)
method = pay_customer.add_payment_method(
  "wallet_123",
  payment_method_type: "bitcoin",
  wallet_address: "1A1z7agoat4hcoraFB19qYbSHwp5EMCv"
)

# Mark as default
method.mark_default!

# List payment methods
pay_customer.payment_methods
```

## Refunds

**Note:** BTCPay does not support automatic refunds through the API. Refunds must be processed manually:

```ruby
# This will raise NotImplementedError
charge.refund!  # ❌ Not supported

# Instead, manually refund:
# 1. Log in to your BTCPay instance
# 2. View the invoice
# 3. Send a refund transaction from your wallet
# 4. Update Pay records manually if needed
```

If you need refund support, consider using a centralized exchange that accepts cryptocurrency alongside a traditional payment processor.

## Webhooks

### Setting Up Webhooks

In your BTCPay instance:
1. Go to Settings → Webhooks
2. Add a new webhook pointing to:
   ```
   https://your-app.com/pay/webhooks/btcpay
   ```
3. Select events:
   - Invoice Created
   - Invoice Received Payment
   - Invoice Payment Settled
   - Invoice Expired
   - Payment Request Received
   - Payment Request Expired

### Webhook Events

The gem automatically handles:

- `btcpay.charge.completed` - Invoice payment settled
- `btcpay.charge.failed` - Invoice expired
- `btcpay.payment_received` - Payment received (unconfirmed)
- `btcpay.subscription.payment_received` - Subscription payment received
- `btcpay.subscription.expired` - Subscription expired

## Multi-Currency Support

BTCPay stores prices in fiat currency and displays equivalent cryptocurrency amounts:

```ruby
# USD
pay_customer.charge(10_000, currency: "USD")

# EUR
pay_customer.charge(8_500, currency: "EUR")

# GBP
pay_customer.charge(7_300, currency: "GBP")

# Cryptocurrency (direct pricing)
pay_customer.charge(50_000_000, currency: "SATS")  # Satoshis
```

## Lightning Network Payments

Lightning Network enables instant, zero-fee payments:

```ruby
charge = pay_customer.charge(
  1_000,
  currency: "USD",
  description: "Coffee"
)

# Invoice will include both on-chain and Lightning payment options
# Lightning payment will settle instantly
invoice_data = charge.data
# Contains:
# - charge.data["invoiceTime"]
# - charge.data["url"] (shareable link with Lightning QR)
# - charge.data["supportedTransactionCurrencies"] (BTC, SATS, etc.)
```

## Testing Cryptocurrency Payments

For development, use a testnet BTCPay Server:

```ruby
# config/initializers/pay.rb (development only)
if Rails.env.development?
  Pay::Btcpay.configure do |config|
    config.api_url = "https://testnet.demo.btcpayserver.org"
    config.api_key = ENV["BTCPAY_TESTNET_API_KEY"]
    config.store_id = ENV["BTCPAY_TESTNET_STORE_ID"]
  end
end
```

## Advantages of Crypto Payments

1. **Lower Fees** - 0% payment processor fees (only mining/network fees)
2. **Instant Settlement** - No chargeback risk
3. **Global** - Accept payments from anywhere without intermediaries
4. **Privacy** - Minimal customer data required
5. **Decentralized** - Not subject to payment processor policies
6. **Programmable** - Direct API access without restrictions

## Privacy Considerations

- No personal information required for payment
- Blockchain is pseudonymous (not anonymous)
- Customers can use new addresses for each transaction
- Consider implementing GDPR-compliant retention policies

## Common Patterns

### Email-based Invoice Distribution

```ruby
class InvoiceMailer < ApplicationMailer
  def payment_request(charge)
    @invoice_url = charge.data["url"]
    @amount = charge.amount
    
    mail(
      to: charge.customer.owner.email,
      subject: "Payment Request - #{@amount}"
    )
  end
end

# In your order controller
InvoiceMailer.payment_request(charge).deliver_later
```

### QR Code Display

```erb
<div id="invoice">
  <img src="<%= @charge.data["cryptoData"]["qr"]["bip72"] %>" alt="Payment QR Code">
  <p><%= @charge.data["url"] %></p>
</div>
```

### Polling for Payment Status

```ruby
# Client-side (JavaScript) or server-side polling
def check_payment_status
  charge = Pay::Charge.find(params[:id])
  Pay::Charge.sync(charge.processor_id)
  
  render json: {
    status: charge.reload.charged? ? "settled" : "pending"
  }
end
```

## Troubleshooting

### "BTCPay API Error: 403"
- Verify your API key is correct
- Check that your store ID matches
- Confirm the API key has required permissions

### Invoice expires quickly
- Default expiration is 15 minutes
- Increase with: `expiry_window: 3600` (1 hour)

### Payment not received
- Check blockchain confirmations
- Verify webhook URL is accessible
- Test webhook delivery in BTCPay dashboard

### Rate limiting
- BTCPay has API rate limits
- Implement exponential backoff for retries

## Related Documentation

- [BTCPay Server Documentation](https://docs.btcpayserver.org/)
- [BTCPay API Reference](https://docs.btcpayserver.org/API/Greenfield/v1/)
- [Lightning Network](https://lightning.network/)
- [Bitcoin Privacy Guide](https://en.bitcoin.it/wiki/Privacy)
