require 'test_helper'

class Pay::Stripe::ChargeRenewingTest < ActiveSupport::TestCase
  setup do
    @event = OpenStruct.new
    @event.data = JSON.parse(File.read('test/support/fixtures/subscription_renewing_event.json'), object_class: OpenStruct)
  end

  test "an email is sent to the user when subscription is renewing" do
    @user = User.create!(email: 'gob@bluth.com', processor: :stripe, processor_id: @event.data.object.customer)
    subscription = @user.subscriptions.create!(processor: :stripe, processor_id: @event.data.object.subscription, name: 'default', processor_plan: 'some-plan')

    mailer = mock('mailer')
    Pay.stubs(:send_emails).returns(true)
    Pay::UserMailer.expects(:subscription_renewing).with(@user, subscription).returns(mailer)
    mailer.expects(:deliver_later)
    Pay::Stripe::SubscriptionRenewing.new.call(@event)

  end
end