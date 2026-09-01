require "webmock/minitest"

# Square has no VCR cassettes; we WebMock the API directly and eject the per-test
# cassette that support/vcr.rb inserts.
module Pay
  module Square
    class TestCase < ActiveSupport::TestCase
      setup do
        VCR.eject_cassette while VCR.current_cassette
        WebMock.reset!
        WebMock.disable_net_connect!

        # @square_token_calls lets tests assert the 401 force-refresh retry.
        @square_token_calls = []
        Pay::Square.access_token_provider = ->(pay_customer, force_refresh = false) do
          @square_token_calls << {customer: pay_customer, force_refresh: force_refresh}
          force_refresh ? "fresh-token" : "test-token"
        end
      end

      teardown do
        Pay::Square.access_token_provider = nil
        WebMock.reset!
        WebMock.allow_net_connect!
      end

      # https://connect.squareupsandbox.com/v2/<path>
      def square_url(path)
        "#{Pay::Square.base_url}/v2/#{path}"
      end

      def stub_square(method, path, status: 200, response: {}, request_body: nil)
        stub = stub_request(method, square_url(path))
        stub = stub.with(body: request_body) if request_body
        stub.to_return(
          status: status,
          body: response.to_json,
          headers: {"Content-Type" => "application/json"}
        )
      end

      def square_payment_json(overrides = {})
        {
          id: "pmt_test",
          order_id: "ord_test",
          status: "COMPLETED",
          customer_id: "sqcust_test",
          amount_money: {amount: 10_00, currency: "USD"},
          app_fee_money: {amount: 1_00, currency: "USD"},
          refunded_money: {amount: 0, currency: "USD"},
          created_at: "2026-09-01T00:00:00Z",
          card_details: {card: {last_4: "1111", card_brand: "VISA", exp_month: 12, exp_year: 2030}}
        }.merge(overrides)
      end

      def square_card_json(overrides = {})
        {
          id: "card_test",
          customer_id: "sqcust_test",
          last_4: "4242",
          card_brand: "VISA",
          exp_month: 4,
          exp_year: 2031
        }.merge(overrides)
      end
    end
  end
end
