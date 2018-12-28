module Pay
  class EmailSyncJob < ApplicationJob
    queue_as :default

    def perform(user_id)
      user = User.find(user_id)
      user.sync_email_with_processor
    rescue ActiveRecord::RecordNotFound
      Rails.logger.info "Couldn't find a user with ID = #{user_id}"
    end
  end
end
