module Pay
  module Lago
    module Webhooks
      class InvoiceDrafted
        def call(event)
          Pay::Lago::Charge.sync(event.invoice.lago_id, object: event.invoice)
        end
      end
    end
  end
end
