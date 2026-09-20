require "test_helper"

class Pay::Stripe::MerchantTest < ActiveSupport::TestCase
  test "login_link passes options through to Stripe" do
    merchant = pay_merchants(:one)
    merchant.update!(processor_id: "acct_123")
    login_link = ::Stripe::LoginLink.construct_from(object: "login_link", url: "https://connect.stripe.com/express/login")
    ::Stripe::Account.expects(:create_login_link).with("acct_123", {expand: ["url"]}).returns(login_link)

    assert_equal login_link, merchant.login_link(expand: ["url"])
  end
end
