require "test_helper"

class Pay::AwsMarketplace::CustomerTest < ActiveSupport::TestCase
  setup do
    @pay_customer = pay_customers(:aws_marketplace)
  end

  test "allows aws_marketplace processor" do
    assert_nothing_raised do
      users(:none).set_payment_processor :aws_marketplace
    end
  end

  test "aws processor api_record" do
    assert_equal @pay_customer.api_record, {customer_identifier: "QzOTBiMmRmN"}
  end

  test "aws processor charge" do
    assert_raises Pay::AwsMarketplace::ChargeError do
      @pay_customer.charge(10_00)
    end
  end

  test "aws processor subscribe" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @pay_customer.subscribe
    end
  end

  test "aws processor subscribe with promotion code" do
    assert_raises Pay::AwsMarketplace::UpdateError do
      @pay_customer.subscribe(promotion_code: "promo_xxx123")
    end
  end

  test "aws processor add new default payment method" do
    assert_raises Pay::AwsMarketplace::PaymentMethodError do
      @pay_customer.add_payment_method("new", default: true)
    end
  end

  test "aws customer stores aws account id" do
    user = users(:none)
    pay_customer = user.set_payment_processor :aws_marketplace
    assert_nil pay_customer.processor_id
    assert_nil pay_customer.aws_account_id
    pay_customer.update!(processor_id: "bwhUQyJL8sd", aws_account_id: "25404655876")
    assert_not_nil pay_customer.processor_id
    assert_not_nil pay_customer.aws_account_id
  end

  test "aws customer update api record" do
    user = users(:none)
    pay_customer = user.set_payment_processor :aws_marketplace

    assert_raises Pay::AwsMarketplace::UpdateError do
      pay_customer.update_api_record(
        "customer_identifier" => "bwhUQyJL8sd", "customer_aws_account_id" => "25404655876"
      )
    end
  end
end
