module Pay
  module Receipts
    def product
      Pay.application_name
    end

    def receipt_filename
      "receipt-#{created_at.strftime("%Y-%m-%d")}.pdf"
    end
    alias_method :filename, :receipt_filename

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
          email: Pay.support_email
        },
        line_items: line_items
      )
    end

    def invoice_filename
      "invoice-#{created_at.strftime("%Y-%m-%d")}.pdf"
    end

    def invoice
      invoice_pdf.render
    end

    def invoice_pdf
      ::Receipts::Invoice.new(
        id: id,
        issue_date: created_at,
        due_date: created_at,
        status: "<b><color rgb='#5eba7d'>PAID</color></b>",
        bill_to: [
          customer.customer_name,
          customer.email
        ].compact,
        product: product,
        company: {
          name: Pay.business_name,
          address: Pay.business_address,
          email: Pay.support_email
        },
        line_items: line_items
      )
    end

    def line_items
      line_items = [
        [I18n.t("receipt.date"), created_at.to_s],
        [I18n.t("receipt.account_billed"), "#{customer.customer_name} (#{customer.email})"],
        [I18n.t("receipt.product"), product],
        [I18n.t("receipt.amount"), ActionController::Base.helpers.number_to_currency(amount / 100.0)],
        [I18n.t("receipt.charged_to"), charged_to]
      ]
      line_items << [I18n.t("receipt.additional_info"), customer.owner.extra_billing_info] if customer.owner.extra_billing_info?
      line_items
    end
  end
end
