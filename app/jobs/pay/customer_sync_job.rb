module Pay
  class CustomerSyncJob < ApplicationJob
    def perform(pay_customer_id)
      Pay::Customer.find(pay_customer_id).update_customer!
    rescue ActiveRecord::RecordNotFound
      Rails.logger.info "Couldn't find a Pay::Customer with ID = #{pay_customer_id}"
    end
  end
end
