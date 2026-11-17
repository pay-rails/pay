require "test_helper"

class Pay::Stripe::MerchantTest < ActiveSupport::TestCase
  test "login_link passes options through to Stripe" do
    merchant = pay_merchants(:stripe)
    merchant.update!(processor_id: "acct_123")
    login_link = ::Stripe::LoginLink.construct_from(object: "login_link", url: "https://connect.stripe.com/express/login")
    ::Stripe::Account.expects(:create_login_link).with("acct_123", {expand: ["url"]}, {}).returns(login_link)

    assert_equal login_link, merchant.login_link(expand: ["url"])
  end

  test "account uses the API key scoped with with_request_options" do
    merchant = pay_merchants(:stripe)
    merchant.update!(processor_id: "acct_123")
    ::Stripe::Account.expects(:retrieve).with("acct_123", {api_key: "sk_other_platform"}).returns(:account)

    Pay::Stripe.with_request_options(api_key: "sk_other_platform") do
      assert_equal :account, merchant.account
    end
  end
end
