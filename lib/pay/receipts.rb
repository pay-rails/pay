module Pay
  module Receipts
    include ActionView::Helpers::NumberHelper

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

    def receipt_pdf(**options)
      defaults = {
        id: id,
        product: product,
        company: {
          name: Pay.business_name,
          address: Pay.business_address,
          email: Pay.support_email,
          logo: Pay.business_logo
        },
        line_items: line_items
      }

      ::Receipts::Receipt.new(defaults.deep_merge(options))
    end

    def invoice_filename
      "invoice-#{created_at.strftime("%Y-%m-%d")}.pdf"
    end

    def invoice
      invoice_pdf.render
    end

    def invoice_pdf(**options)
      defaults = {
        id: id,
        issue_date: I18n.l(created_at, format: :long),
        due_date: I18n.l(created_at, format: :long),
        status: "<b><color rgb='#5eba7d'>#{I18n.t("pay.receipt.paid").upcase}</color></b>",
        bill_to: [
          customer.customer_name,
          customer.email
        ].compact,
        product: product,
        company: {
          name: Pay.business_name,
          address: Pay.business_address,
          email: Pay.support_email,
          logo: Pay.business_logo
        },
        line_items: line_items
      }

      ::Receipts::Invoice.new(defaults.deep_merge(options))
    end

    def line_items
      line_items = [
        [I18n.t("pay.receipt.date"), I18n.l(created_at, format: :long)],
        [I18n.t("pay.receipt.account_billed"), "#{customer.customer_name} (#{customer.email})"],
        [I18n.t("pay.receipt.product"), product],
        [I18n.t("pay.receipt.amount"), number_to_currency(amount / 100.0)],
        [I18n.t("pay.receipt.charged_to"), charged_to]
      ]
      line_items << [I18n.t("pay.receipt.additional_info"), customer.owner.extra_billing_info] if customer.owner.extra_billing_info?
      line_items << [I18n.t("pay.receipt.refunded"), number_to_currency(amount_refunded / 100.0)] if refunded?
      line_items
    end
  end
end
