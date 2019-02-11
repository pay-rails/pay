module Pay
  module Receipts
    def filename
      "receipt-#{created_at.strftime('%Y-%m-%d')}.pdf"
    end

    # Must return a file object
    def receipt
      receipt_pdf.render
    end

    def receipt_pdf
      Receipts::Receipt.new(
        id: id,
        product: Pay.config.application_name,
        company: {
          name:    Pay.config.business_name,
          address: Pay.config.business_address,
          email:   Pay.config.support_email,
        },
        line_items: line_items
      )
    end

    def line_items
      line_items = [
        ["Date",           created_at.to_s],
        ["Account Billed", "#{owner.name} (#{owner.email})"],
        ["Product",        Pay.config.application_name],
        ["Amount",         ActionController::Base.helpers.number_to_currency(amount / 100.0)],
        ["Charged to",     charged_to],
      ]
      line_items << ["Additional Info", owner.extra_billing_info] if owner.extra_billing_info?
      line_items
    end
  end
end
