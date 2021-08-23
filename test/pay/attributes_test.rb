require "test_helper"

class Pay::AttributesTest < ActiveSupport::TestCase
  test "set payment processor" do
    user = users(:none)

    assert_difference "Pay::Customer.count" do
      assert_indexed_selects do
        user.set_payment_processor :stripe
      end
    end
  end

  test "set payment processor with previously deleted processor" do
    user = users(:deleted_customer)
    assert user.pay_customers.last.deleted_at?

    assert_difference "Pay::Customer.where(processor: :stripe).count" do
      user.set_payment_processor :stripe
    end

    assert user.payment_processor
  end

  test "deleting user doesn't remove pay customers" do
    Pay::Subscription.any_instance.expects(:cancel_now!)
    assert_no_difference "Pay::Customer.count" do
      users(:stripe).destroy
    end
  end
end
