require "test_helper"

class Pay::Square::PaymentMethodTest < Pay::Square::TestCase
  setup do
    @user = users(:none)
    @pay_customer = @user.set_payment_processor(:square, square_account: "MERCHANT_1")
    @pay_customer.update!(processor_id: "sqcust_test")
  end

  test "sync persists a Square card on file" do
    stub_square(:get, "cards/card_test", response: {card: square_card_json})

    pay_payment_method = Pay::Square::PaymentMethod.sync("card_test", pay_customer: @pay_customer)
    assert_equal "card_test", pay_payment_method.processor_id
    assert_equal "card", pay_payment_method.payment_method_type
    assert_equal "VISA", pay_payment_method.brand
    assert_equal "4242", pay_payment_method.last4
    assert_equal "4", pay_payment_method.exp_month
    assert_equal "2031", pay_payment_method.exp_year
    assert_equal "MERCHANT_1", pay_payment_method.square_account
  end
end
