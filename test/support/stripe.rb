class ActiveSupport::TestCase
  private

  def fake_stripe_payment_method(**values)
    values.reverse_merge!(
      id: "pm_123",
      object: "payment_method",
      billing_details: {
        address: {
          city: nil,
          country: nil,
          line1: nil,
          line2: nil,
          postal_code: "42424",
          state: nil
        },
        email: "jenny@example.com",
        name: nil,
        phone: "+15555555555"
      },
      card: {
        brand: "visa",
        checks: {
          address_line1_check: nil,
          address_postal_code_check: nil,
          cvc_check: "pass"
        },
        country: "US",
        exp_month: 8,
        exp_year: 2024,
        fingerprint: "eLihtj2HTMlWeL7e",
        funding: "credit",
        generated_from: nil,
        last4: "4242",
        networks: {
          available: [
            "visa"
          ],
          preferred: nil
        },
        three_d_secure_usage: {
          supported: true
        },
        wallet: nil
      },
      created: 123456789,
      customer: "cus_1234",
      livemode: false,
      metadata: {
        order_id: "123456789"
      },
      type: "card"
    )
    ::Stripe::PaymentMethod.construct_from(values)
  end

  def fake_stripe_subscription_with_metered_item
    fake_stripe_subscription(quantity: nil, items: {
      object: "list",
      data: [
        ::Stripe::Subscription.construct_from(
          id: "si_KjcLsWCXBgVRuU",
          object: "subscription_item",
          created: 1638904425,
          metadata: {},
          price: {
            id: "large-monthly",
            recurring: {
              aggregate_usage: "sum",
              interval: "month",
              interval_count: 1,
              usage_type: "metered"
            }
          }
        )
      ],
      has_more: false
    })
  end

  def fake_stripe_subscription(**values)
    values.reverse_merge!(
      id: "123",
      object: "subscription",
      application_fee_percent: nil,
      cancel_at: nil,
      cancel_at_period_end: false,
      created: 1466783124,
      current_period_end: 1488987924,
      current_period_start: 1486568724,
      customer: "cus_1234",
      default_payment_method: nil,
      ended_at: nil,
      latest_invoice: {
        id: "in_1000",
        status: "paid"
      },
      plan: {
        id: "default"
      },
      price: {
        id: "default"
      },
      quantity: 1,
      status: "active",
      trial_end: nil,
      metadata: {
        license_id: 1
      },
      pause_collection: nil,
      items: {
        object: "list",
        data: [
          {
            id: "si_1",
            object: "subscription_item",
            billing_threshold: nil,
            created: 1638904425,
            metadata: {},
            price: {
              id: "default",
              object: "price",
              active: true,
              aggregate_usage: nil,
              amount: 10000,
              amount_decimal: "10000",
              billing_scheme: "per_unit",
              created: 1571425606,
              currency: "usd",
              interval: "month",
              interval_count: 1,
              livemode: false,
              metadata: {},
              nickname: "Large Monthly",
              product: "prod_EYTX7RYhRjcwKD",
              usage_type: "licensed"
            },
            quantity: 1,
            subscription: "123",
            tax_rates: []
          }
        ],
        has_more: false,
        total_count: 1,
        url: "/v1/subscription_items?subscription=123"
      }
    )
    ::Stripe::Subscription.construct_from(values)
  end
end
