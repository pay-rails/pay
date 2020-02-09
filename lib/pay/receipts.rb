module Pay
  module Receipts
    def filename
      "receipt-#{created_at.strftime("%Y-%m-%d")}.pdf"
    end

    def product
      Pay.application_name
    end

    # Must return a file object
    def receipt
      receipt_pdf.render
    end

    def receipt_pdf
      ::Receipts::Receipt.new(
        id: id,
        product: product,
        company: {
          name: Pay.business_name,
          address: Pay.business_address,
          email: Pay.support_email,
        },
        line_items: line_items
      )
    end

    def line_items
      line_items = [
        ["Date", created_at.to_s],
        ["Account Billed", "#{owner.name} (#{owner.email})"],
        ["Product", product],
        ["Amount", ActionController::Base.helpers.number_to_currency(amount / 100.0)],
        ["Charged to", charged_to],
      ]
      line_items << ["Additional Info", owner.extra_billing_info] if owner.extra_billing_info?
      line_items
    end
  end
end
