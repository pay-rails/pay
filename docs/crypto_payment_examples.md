# Cryptocurrency Payment Examples

## Basic Setup

### 1. Initialize Configuration

```ruby
# config/initializers/pay.rb

Pay::Btcpay.configure do |config|
  config.api_url = ENV.fetch("BTCPAY_API_URL")
  config.api_key = ENV.fetch("BTCPAY_API_KEY")
  config.store_id = ENV.fetch("BTCPAY_STORE_ID")
end

# Subscribe to crypto payment events
Pay.subscribe("btcpay.charge.completed") do |event|
  CryptoPaymentMailer.payment_confirmed(event.charge).deliver_later
end

Pay.subscribe("btcpay.subscription.payment_received") do |event|
  User.find(event.subscription.customer.owner_id).renew_subscription!
end
```

## One-Time Payments

### 2. Create a Product Purchase

```ruby
class OrdersController < ApplicationController
  def create
    @order = Order.create!(order_params)
    pay_customer = current_user.payment_processor("btcpay")
    
    charge = pay_customer.charge(
      @order.total_amount_cents,
      currency: "USD",
      description: "Order ##{@order.id}",
      order_id: @order.id,
      redirect_url: order_path(@order, confirmed: true),
      success_url: order_path(@order, confirmed: true)
    )
    
    # Store invoice URL on order
    @order.update(crypto_invoice_url: charge.data["url"])
    
    # Redirect to payment page
    redirect_to charge.data["url"], allow_other_host: true
  end

  def show
    @order = Order.find(params[:id])
    if params[:confirmed]
      @order.charges.first&.sync  # Poll for latest status
    end
  end
end
```

### 3. Digital Product Sale

```ruby
class DigitalProductsController < ApplicationController
  def purchase
    product = DigitalProduct.find(params[:id])
    pay_customer = current_user.payment_processor("btcpay")
    
    charge = pay_customer.charge(
      product.price_cents,
      currency: "USD",
      description: "Digital Product: #{product.name}",
      metadata: {
        product_id: product.id,
        user_id: current_user.id
      }
    )
    
    # Create a purchase record
    purchase = Purchase.create!(
      user: current_user,
      digital_product: product,
      crypto_charge_id: charge.id,
      status: "pending_payment"
    )
    
    # Email payment link
    DigitalProductMailer.payment_link(purchase, charge.data["url"]).deliver_later
    
    render json: { invoice_url: charge.data["url"] }
  end
end
```

### 4. Custom Payment Request

```ruby
class PaymentRequestsController < ApplicationController
  def create
    @request = PaymentRequest.create!(
      user: current_user,
      description: params[:description],
      amount_cents: params[:amount_cents],
      currency: "USD"
    )
    
    pay_customer = current_user.payment_processor("btcpay")
    
    charge = pay_customer.charge(
      @request.amount_cents,
      currency: @request.currency,
      description: @request.description,
      order_id: "request_#{@request.id}",
      notification_url: webhook_url("btcpay"),
      success_url: payment_success_url(@request)
    )
    
    @request.update(processor_id: charge.processor_id)
    
    render json: {
      url: charge.data["url"],
      qr_code: charge.data["cryptoData"]["qr"]
    }
  end
end
```

## Recurring Payments

### 5. Subscription Setup

```ruby
class SubscriptionsController < ApplicationController
  def create
    plan = Plan.find(params[:plan_id])
    pay_customer = current_user.payment_processor("btcpay")
    
    subscription = pay_customer.subscribe(
      "subscription_#{current_user.id}",
      amount: plan.price_cents,
      currency: "USD",
      period: "month",
      interval_count: 1,
      description: "#{plan.name} Subscription",
      success_url: subscription_path(id: "NEW"),
      expired_url: subscription_path(id: "NEW", expired: true)
    )
    
    # Store subscription details
    user_subscription = UserSubscription.create!(
      user: current_user,
      plan: plan,
      processor_id: subscription.processor_id,
      status: "pending_payment"
    )
    
    # Redirect to payment
    redirect_to subscription.data["url"], allow_other_host: true
  end
  
  def cancel
    subscription = current_user.subscriptions.find(params[:id])
    subscription.cancel
    
    respond_to do |format|
      format.json { render json: { status: "cancelled" } }
    end
  end
  
  def pause
    subscription = current_user.subscriptions.find(params[:id])
    subscription.pause
    
    respond_to do |format|
      format.json { render json: { status: "paused" } }
    end
  end
  
  def resume
    subscription = current_user.subscriptions.find(params[:id])
    subscription.resume
    
    respond_to do |format|
      format.json { render json: { status: "active" } }
    end
  end
end
```

## Webhook Handling

### 6. Webhook Verification and Processing

```ruby
class Pay::WebhooksController < Pay::ApplicationController
  # In routes.rb: post "/pay/webhooks/btcpay", to: "pay/webhooks#create", as: :btcpay_webhook

  def create
    if params[:type] == "WebhookInvoiceEvent"
      payload = params[:data]
      event_type = params[:type]
      
      Pay::Webhooks::Btcpay.handle(params, payload)
      
      head :ok
    else
      head :bad_request
    end
  rescue => e
    Rails.logger.error("BTCPay Webhook Error: #{e.message}")
    head :internal_server_error
  end
end
```

### 7. Payment Confirmation Flow

```ruby
# app/mailers/payment_mailer.rb
class PaymentMailer < ApplicationMailer
  default from: "payments@example.com"
  
  def payment_confirmation(charge)
    @charge = charge
    @user = charge.customer.owner
    
    mail(
      to: @user.email,
      subject: "Payment Received - #{@charge.amount / 100}"
    )
  end
  
  def payment_pending(charge)
    @charge = charge
    @user = charge.customer.owner
    @invoice_url = charge.data["url"]
    
    mail(
      to: @user.email,
      subject: "Complete Your Payment"
    )
  end
end

# Subscribe to events
Pay.subscribe("btcpay.charge.completed") do |event|
  PaymentMailer.payment_confirmation(event.charge).deliver_later
end

Pay.subscribe("btcpay.payment_received") do |event|
  PaymentMailer.payment_pending(event.charge).deliver_later
end
```

## Advanced Patterns

### 8. Multi-Currency Pricing

```ruby
class Product < ApplicationRecord
  def crypto_price(currency = "USD")
    case currency
    when "EUR"
      (price_usd * 0.92).to_i
    when "GBP"
      (price_usd * 0.80).to_i
    else
      price_usd
    end
  end
  
  def charge_in_crypto(user, currency: "USD")
    pay_customer = user.payment_processor("btcpay")
    
    pay_customer.charge(
      crypto_price(currency) * 100,  # Convert to cents
      currency: currency,
      description: name
    )
  end
end
```

### 9. Payment Status Polling

```javascript
// app/assets/javascripts/crypto_payments.js

async function pollPaymentStatus(chargeId) {
  const maxAttempts = 60;  // 5 minutes with 5-second intervals
  let attempts = 0;
  
  while (attempts < maxAttempts) {
    const response = await fetch(`/charges/${chargeId}/status`);
    const data = await response.json();
    
    if (data.status === "settled") {
      return true;
    } else if (data.status === "expired") {
      return false;
    }
    
    await new Promise(resolve => setTimeout(resolve, 5000));
    attempts++;
  }
  
  return false;
}
```

### 10. Admin Payment Dashboard

```ruby
class Admin::CryptoPaymentsController < AdminController
  def index
    @charges = Pay::Charge.where(processor: "btcpay").order(created_at: :desc)
    @pending = @charges.where("data->>'status' = ?", "new")
    @confirmed = @charges.where("data->>'status' = ?", "settled")
  end
  
  def sync
    charge = Pay::Charge.find(params[:id])
    Pay::Charge.sync(charge.processor_id)
    
    redirect_back fallback_location: admin_crypto_payments_path,
                  notice: "Charge synced"
  end
  
  def retry_webhook
    charge = Pay::Charge.find(params[:id])
    Pay::Webhooks::Btcpay.handle_invoice_payment_settled(charge.data)
    
    redirect_back fallback_location: admin_crypto_payments_path,
                  notice: "Webhook redelivered"
  end
end
```

## Views and UI

### 11. Payment Button Component

```erb
<!-- app/components/crypto_payment_button.html.erb -->
<div class="crypto-payment">
  <%= link_to "Pay with Crypto", 
              @charge.data["url"],
              class: "btn btn-primary btn-lg",
              target: "_blank",
              rel: "noopener noreferrer" %>
  
  <div class="payment-info mt-3">
    <p>Amount: <%= number_to_currency(@charge.amount / 100.0) %></p>
    <p>Invoice ID: <code><%= @charge.processor_id %></code></p>
  </div>
  
  <div id="payment-status" class="mt-3">
    <p><span class="badge badge-info">Awaiting Payment</span></p>
  </div>
</div>

<script>
  document.addEventListener('DOMContentLoaded', () => {
    pollPaymentStatus('<%= @charge.id %>');
  });
</script>
```

### 12. QR Code Display

```erb
<!-- app/components/crypto_qr_code.html.erb -->
<div class="crypto-qr">
  <h3>Scan to Pay</h3>
  
  <% if @charge.data["cryptoData"] %>
    <img src="<%= @charge.data["cryptoData"]["qr"]["bip72"] %>" 
         alt="Bitcoin Payment QR Code"
         class="qr-code">
    
    <div class="payment-details mt-3">
      <p>Amount: <%= @charge.data["cryptoData"]["BTC"]["amount"] %> BTC</p>
      <p>Address: <code><%= @charge.data["cryptoData"]["BTC"]["address"] %></code></p>
    </div>
  <% end %>
</div>
```

## Error Handling

### 13. Retry Logic with Exponential Backoff

```ruby
class CryptoPaymentSyncJob
  include Sidekiq::Worker
  sidekiq_options retry: 5
  
  sidekiq_retry_in do |count|
    60 * (2 ** count)  # Exponential backoff
  end
  
  def perform(charge_id)
    charge = Pay::Charge.find(charge_id)
    Pay::Charge.sync(charge.processor_id)
  rescue => e
    Rails.logger.error("Failed to sync charge #{charge_id}: #{e.message}")
    raise e
  end
end

# Schedule sync after payment request
Pay.subscribe("btcpay.payment_received") do |event|
  CryptoPaymentSyncJob.perform_in(30.seconds, event.charge.id)
end
```

## Testing

### 14. Test Fixtures

```ruby
# test/fixtures/btcpay_invoices.yml
test_invoice:
  id: "invoice_test_123"
  status: "new"
  amount: 100.00
  currency: "USD"
  invoiceTime: <%= Time.now.to_i %>
  expirationTime: <%= (Time.now + 15.minutes).to_i %>
  url: "https://demo.btcpayserver.org/invoice/test"
  cryptoData:
    BTC:
      amount: "0.00234"
      address: "1A1z7agoat4hcoraFB19qYbSHwp5EMCv"

# test/models/pay/btcpay/charge_test.rb
class Pay::Btcpay::ChargeTest < ActiveSupport::TestCase
  setup do
    @charge = pay_charges(:test_charge)
  end
  
  test "charge is created successfully" do
    assert @charge.processor == "btcpay"
    assert @charge.processor_id.present?
  end
end
```

## Production Checklist

- [ ] Configure API credentials in environment variables
- [ ] Set up webhook endpoint and verify signature
- [ ] Enable HTTPS for all payment endpoints
- [ ] Test refund procedures (manual process)
- [ ] Set up logging for payment events
- [ ] Create admin dashboard for monitoring
- [ ] Implement payment polling for confirmation
- [ ] Test with testnet first
- [ ] Document customer payment flow
- [ ] Set up email notifications
- [ ] Configure rate limiting
- [ ] Test blockchain network recovery scenarios
