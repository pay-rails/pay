require "test_helper"

class Pay::WebhookDelegatorTest < ActiveSupport::TestCase
  class TestEventProcessor
    attr_accessor :success

    def call(event)
      @success = true
    end
  end

  setup do
    @delegator = Pay::Webhooks::Delegator.new
  end

  test "pay has a default delegator" do
    assert_not_nil Pay::Webhooks.delegator
  end

  test "subscribe includes namespace" do
    delegator.subscribe "stripe.test_event", ->(event) {}
    assert delegator.backend.notifier.listening?("pay.stripe.test_event")
  end

  test "instruments events" do
    success = nil

    delegator.subscribe "stripe.test_event" do |event|
      success = true
    end

    delegator.instrument event: {}, type: "stripe.test_event"
    assert success
  end

  test "can subscribe with class" do
    processor = TestEventProcessor.new
    delegator.subscribe "stripe.test_event", processor
    delegator.instrument event: {}, type: "stripe.test_event"
    assert processor.success
  end

  test "can unsubscribe" do
    delegator.subscribe "stripe.test_event", ->(event) {}
    assert delegator.backend.notifier.listening?("pay.stripe.test_event")
    delegator.unsubscribe "stripe.test_event"
    assert delegator.backend.notifier.listening?("pay.stripe.test_event")
  end

  test "supports multiple subscriptions for the same event" do
    results = []

    delegator.subscribe "stripe.test_event" do |event|
      results << "a"
    end

    delegator.subscribe "stripe.test_event" do |event|
      results << "b"
    end

    delegator.instrument event: {}, type: "stripe.test_event"
    assert_equal 2, results.length
  end

  test "listening?" do
    refute delegator.listening?("example.test_event")
    delegator.subscribe "example.test_event", ->(event) {}
    assert delegator.listening?("example.test_event")
  end

  private

  attr_reader :delegator
end
