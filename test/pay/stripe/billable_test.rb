require "test_helper"

class Pay::Stripe::BillableTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "gob@bluth.com", processor: :stripe)

    # Create Stripe customer
    @user.customer
  end

  test "stripe subscription and one time charge" do
    @user.update_card("pm_card_visa")
    @user.subscribe(
      name: "default",
      plan: "default",
      add_invoice_items: [
        {price: "price_1ILVZaKXBGcbgpbZQ26kgXWG"} # T-Shirt $15
      ]
    )

    invoice_id = Pay::Subscription.last.processor_subscription.latest_invoice
    invoice = ::Stripe::Invoice.retrieve(invoice_id)
    assert_equal 25_00, invoice.total
    assert_not_nil invoice.lines.data.find { |l| l.plan&.id == "default" }
    assert_not_nil invoice.lines.data.find { |l| l.price&.id == "price_1ILVZaKXBGcbgpbZQ26kgXWG" }
  end

  test "stripe saves currency on charge" do
    @user.card_token = "pm_card_visa"
    charge = @user.charge(29_00)
    assert_equal "usd", charge.currency
  end
end
