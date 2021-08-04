module Pay
  class CustomerSyncJob < ApplicationJob
    queue_as :default

    def perform(pay_customer_id)
      Pay::Customer.find(pay_customer_id).update_customer!
    rescue ActiveRecord::RecordNotFound
      Rails.logger.info "Couldn't find a #{class_name} with ID = #{id}"
    end
  end
end
