module Pay
  class EmailSyncJob < ApplicationJob
    queue_as :default

    def perform(id)
      billable = Pay.billable_class.classify.constantize.find(id)
      billable.sync_email_with_processor
    rescue ActiveRecord::RecordNotFound
      Rails.logger.info "Couldn't find a #{Pay.billable_class} with ID = #{id}"
    end
  end
end
