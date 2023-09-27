module Pay
  module Lago
    module Webhooks
      class InvoicePaymentStatusUpdated
        def call(event)
          charge = Pay::Charge.find_by_processor_and_id(:lago, event.invoice.lago_id)
          return unless charge.present?
          charge.data.merge!(payment_status: event.invoice.payment_status)
          charge.save!
        end
      end
    end
  end
end
