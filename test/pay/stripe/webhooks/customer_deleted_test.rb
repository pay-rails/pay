require "test_helper"

class Pay::Stripe::Webhooks::CustomerDeletedTest < ActiveSupport::TestCase
  setup do
    @event = OpenStruct.new
    @event.data = JSON.parse(File.read("test/support/fixtures/stripe/customer_deleted_event.json"), object_class: OpenStruct)
  end

  test "a customers subscription information is nulled out upon deletion" do
    user = User.create!(
      email: "gob@bluth.com",
      processor: :stripe,
      processor_id: @event.data.object.id,
      card_type: "Visa",
      card_exp_month: 1,
      card_exp_year: 2019,
      card_last4: "4444",
      trial_ends_at: 3.days.from_now
    )
    subscription = user.subscriptions.create!(
      processor: :stripe,
      processor_id: "sub_someid",
      name: "default",
      processor_plan: "some-plan",
      trial_ends_at: 3.days.from_now,
      status: "active"
    )

    Pay::Stripe::Webhooks::CustomerDeleted.new.call(@event)

    assert_nil user.reload.processor_id
    assert_nil user.reload.card_type
    assert_nil user.reload.card_exp_month
    assert_nil user.reload.card_exp_year
    assert_nil user.reload.card_last4
    assert_nil user.reload.trial_ends_at

    assert_nil subscription.reload.trial_ends_at
  end
end
