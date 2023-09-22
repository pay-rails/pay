module Pay
  module Lago
    module Webhooks
      class CustomerPaymentProviderCreated
        def call(event)
          customer = event.customer
          pay_customer = Pay::Customer.find_by(processor_id: customer.external_id)
          unless pay_customer.present?
            Rails.logger.debug "Pay::Customer #{customer.external_id} is not in the database while syncing Payment Information"
            return false
          end

          pay_customer.update!(data: Pay::Lago.openstruct_to_h(customer))
        end
      end
    end
  end
end
