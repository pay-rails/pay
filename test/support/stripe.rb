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
          current_period_end: 1488987924,
          current_period_start: 1486568724,
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
            current_period_end: 1488987924,
            current_period_start: 1486568724,
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

  # Creates a Pay::Stripe::Subscription record for webhook tests to look up
  def create_stripe_subscription(processor_id:, customer: pay_customers(:stripe), trial_ends_at: nil)
    customer.subscriptions.create!(processor_id: processor_id, name: "default", processor_plan: "some-plan", status: "active", trial_ends_at: trial_ends_at)
  end

  def fake_stripe_invoice_payment(**values)
    values.reverse_merge!(
      id: "inpay_1M3USa2eZvKYlo2CBjuwbq0N",
      object: "invoice_payment",
      amount_paid: 2000,
      amount_requested: 2000,
      created: 1391288554,
      currency: "usd",
      invoice: fake_stripe_invoice,
      is_default: true,
      livemode: false,
      payment: {
        type: "payment_intent",
        payment_intent: "pi_103Q0w2eZvKYlo2C364X582Z"
      },
      status: "paid",
      status_transitions: {
        canceled_at: nil,
        paid_at: 1391288554
      }
    )
    ::Stripe::InvoicePayment.construct_from(values)
  end

  def fake_stripe_invoice(**values)
    values.reverse_merge!(
      id: "in_1234",
      parent: {
        subscription_details: {
          subscription: "sub_1234"
        }
      },
      period_start: Time.current,
      period_end: Time.current,
      lines: {object: "list", data: [], has_more: false},
      subtotal: 21_49,
      tax: 3_00,
      total: 24_49,
      total_tax_amounts: [
        {
          amount: 2353,
          inclusive: false,
          tax_rate:
          {
            id: "txr_1KOpM7KXBGcbgpbZB0Op4prs",
            object: "tax_rate",
            active: false,
            country: "US",
            created: 1643833387,
            description: nil,
            display_name: "Sales Tax",
            inclusive: false,
            jurisdiction: "Louisiana",
            livemode: false,
            metadata: {},
            percentage: 9.45,
            state: "LA",
            tax_type: "sales_tax"
          }
        }
      ],
      discounts: ["di_1KgYwKKXBGcbgpbZXaYJPeyI"],
      total_discount_amounts: [
        {amount: 12450, discount: {id: "di_1KgYwKKXBGcbgpbZXaYJPeyI", object: "discount", checkout_session: nil, coupon: {id: "upI7E8nG", object: "coupon", amount_off: nil, created: 1648059609, currency: nil, duration: "forever", duration_in_month: nil, livemode: false, max_redemptions: nil, metadata: {}, name: "Half Off", percent_off: 50.0, redeem_by: nil, times_redeemed: 3, valid: true}, customer: "cus_LNFszTN0gcJ4RH", end: nil, invoice: nil, invoice_item: "ii_1KgYwHKXBGcbgpbZVuQ152QU", promotion_code: nil, start: 1648060185, subscription: nil}}
      ]
    )
    ::Stripe::Invoice.construct_from(values)
  end

  def fake_stripe_charge(**values)
    values.reverse_merge!(
      id: "ch_123",
      customer: "cus_1234",
      amount: 19_00,
      amount_captured: 19_00,
      amount_refunded: nil,
      application_fee_amount: 0,
      balance_transaction: {
        id: "txn_1MiN3gLkdIwHu7ixxapQrznl",
        object: "balance_transaction",
        amount: -400,
        available_on: 1678043844,
        created: 1678043844,
        currency: "usd",
        description: nil,
        exchange_rate: nil,
        fee: 0,
        fee_details: [],
        net: -400,
        reporting_category: "transfer",
        source: "tr_1MiN3gLkdIwHu7ixNCZvFdgA",
        status: "available",
        type: "transfer"
      },
      created: 1546332337,
      currency: "usd",
      invoice: nil,
      payment_intent: "pm_1234",
      payment_method_details: {
        card: {
          exp_month: 1,
          exp_year: 2021,
          last4: "4242",
          brand: "Visa"
        },
        type: "card"
      },
      metadata: {
        license_id: 1
      },
      refunds: {
        object: "list",
        data: [],
        has_more: false,
        total_count: 0,
        url: ""
      },
      receipt_url: "https://pay.stripe.com/receipts/test_receipt"
    )
    ::Stripe::Charge.construct_from(values)
  end
end
