module Pay
  class CustomerSyncJob < ApplicationJob
    def perform(pay_customer_id)
      if (pay_customer = Pay::Customer.active.find_by(id: pay_customer_id))
        pay_customer.update_api_record
      else
        Rails.logger.info "Couldn't find an active Pay::Customer with ID = #{pay_customer_id}"
      end
    end
  end
end
