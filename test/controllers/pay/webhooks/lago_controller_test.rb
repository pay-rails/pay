require "test_helper"

module Pay
  class LagoWebhooksControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
    end

    test "should handle lago post requests" do
      post webhooks_lago_path
      assert_response :bad_request
    end

    test "should parse a lago webhook" do
      lago_event = fake_event("lago/invoice.one_off_created")
      Pay::Webhooks::LagoController.any_instance.expects(:verified_event).returns(lago_event)

      pay_customer = pay_customers(:lago)
      pay_customer.update(processor_id: lago_event.dig("invoice", "customer", "external_id"))

      assert_difference "Pay::Webhook.count" do
        assert_enqueued_with(job: Pay::Webhooks::ProcessJob) do
          post webhooks_lago_path, params: lago_event
          assert_response :success
        end
      end

      assert_difference "Pay::Charge.count" do
        perform_enqueued_jobs
      end
    end
  end
end
