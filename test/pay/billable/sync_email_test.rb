require 'test_helper'

class Pay::Billable::SyncEmail::Test < ActiveSupport::TestCase
  setup do
    @billable = User.new
  end

  test 'email sync' do
    assert @billable.should_sync_email_with_processor?
  end

  test 'email sync should be ignored for billable that delegates email' do
    billable = Team.create(name: "Team 1")
    refute billable.should_sync_email_with_processor?
  end
end
