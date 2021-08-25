require "test_helper"

module Pay
  class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
    end

    test "should handle stripe post requests" do
      post webhooks_stripe_path
      assert_response :bad_request
    end

    test "should parse a stripe webhook" do
      params = {
        "id" => "evt_3JMPQbQK2ZHS99Rk0zZhIl7y",
        "object" => "event",
        "api_version" => "2020-08-27",
        "created" => 1628480731,
        "data" => fake_event("stripe/charge.succeeded"),
        "livemode" => false,
        "pending_webhooks" => 3,
        "request" => {
          "id" => nil,
          "idempotency_key" => "in_1JMOTyQK2ZHS99Rk3k06zB02-initial_attempt-0dee959767cdedcc1"
        },
        "type" => "charge.succeeded"
      }

      stripe_event = ::Stripe::Event.construct_from(params)
      Pay::Webhooks::StripeController.any_instance.expects(:verified_event).returns(stripe_event)
      ::Stripe::Charge.expects(:retrieve).returns(stripe_event.data.object)

      pay_customer = pay_customers(:stripe)
      pay_customer.update(processor_id: stripe_event.data.object.customer)

      assert_difference "Pay::Webhook.count" do
        assert_enqueued_with(job: Pay::Webhooks::ProcessJob) do
          post webhooks_stripe_path, params: params
          assert_response :success
        end
      end

      assert_difference "Pay::Charge.count" do
        perform_enqueued_jobs
      end
    end
  end
end
