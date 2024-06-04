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
      params = stripe_params(livemode: true)
      stripe_event = create_stripe_event(params)

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

    test "should not enqueue a job for a test event if webhook_receive_test_events is false" do
      with_modified_env("STRIPE_WEBHOOK_RECEIVE_TEST_EVENTS" => "false") do
        params = stripe_params(livemode: false)
        create_stripe_event(params)

        assert_no_difference "Pay::Webhook.count" do
          post webhooks_stripe_path, params: params
          assert_response :success
        end
      end
    end

    test "should enqueue a job for a test event if webhook_receive_test_events is true" do
      with_modified_env("STRIPE_WEBHOOK_RECEIVE_TEST_EVENTS" => "true") do
        params = stripe_params(livemode: false)
        create_stripe_event(params)

        assert_difference "Pay::Webhook.count" do
          post webhooks_stripe_path, params: params
          assert_response :success
        end
      end
    end

    private

    def stripe_params(livemode:)
      {
        "id" => "evt_3JMPQbQK2ZHS99Rk0zZhIl7y",
        "object" => "event",
        "api_version" => "2020-08-27",
        "created" => 1628480731,
        "data" => fake_event("stripe/charge.succeeded"),
        "livemode" => livemode,
        "pending_webhooks" => 3,
        "request" => {
          "id" => nil,
          "idempotency_key" => "in_1JMOTyQK2ZHS99Rk3k06zB02-initial_attempt-0dee959767cdedcc1"
        },
        "type" => "charge.succeeded"
      }
    end

    def create_stripe_event(params)
      stripe_event = ::Stripe::Event.construct_from(params)
      Pay::Webhooks::StripeController.any_instance.expects(:verified_event).returns(stripe_event)
      stripe_event
    end

    def with_modified_env(options, &block)
      old_env = ENV.to_hash
      ENV.update(options)
      yield
    ensure
      ENV.update(old_env)
    end
  end
end
