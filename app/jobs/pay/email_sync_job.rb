module Pay
  class EmailSyncJob < ApplicationJob
    queue_as :default

    def perform(id, class_name)
      billable = class_name.constantize.find(id)
      billable.sync_email_with_processor
    rescue ActiveRecord::RecordNotFound
      Rails.logger.info "Couldn't find a #{class_name} with ID = #{id}"
    end
  end
end
