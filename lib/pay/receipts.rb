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

    def receipt_details
      [
        [I18n.t("pay.receipt.number"), id],
        [I18n.t("pay.receipt.date"), I18n.l(created_at, format: :long)],
        [I18n.t("pay.receipt.payment_method"), charged_to]
      ]
    end

    def pdf_line_items
      line_items = [
        [
          "<b>#{I18n.t("pay.line_items.description")}</b>",
          "<b>#{I18n.t("pay.line_items.quantity")}</b>",
          "<b>#{I18n.t("pay.line_items.unit_price")}</b>",
          "<b>#{I18n.t("pay.line_items.amount")}</b>"
        ]
      ]
      # Unit price is stored with the line item
      # Negative amounts shouldn't display quantity
      # Sort by line_items by period_end? oldest to newest
      if charge.line_items.any?
        charge.line_items.each do |li|
          line_items << [li["description"], li["quantity"], Pay::Currency.format(li["unit_amount"], currency: currency), Pay::Currency.format(li["amount"], currency: currency)]
        end
      else
        line_items << [product, 1, Pay::Currency.format(amount, currency: currency), Pay::Currency.format(amount, currency: currency)]
      end

      # If no subtotal, we will display the total
      line_items << [nil, nil, I18n.t("pay.line_items.subtotal"), (subtotal || total)]
      line_items << [nil, nil, I18n.t("pay.line_items.tax"), tax] if tax
      line_items << [nil, nil, I18n.t("pay.line_items.total"), total]
      line_items
    end

    def receipt_pdf(**options)
      receipt_line_items = pdf_line_items

      # Include total paid
      receipt_line_items << [nil, nil, I18n.t("pay.receipt.amount_paid"), Pay::Currency.format(amount, currency: currency)]

      if refunded?
        receipt_line_items << [nil, nil, I18n.t("pay.receipt.refunded_on"), Pay::Currency.format(amount_refunded, currency: currency)]
      end

      defaults = {
        details: receipt_details,
        recipient: [
          customer.customer_name,
          customer.email,
          customer.owner.try(:extra_billing_info)
        ],
        company: {
          name: Pay.business_name,
          address: Pay.business_address,
          email: Pay.support_email,
          logo: Pay.business_logo
        },
        line_items: receipt_line_items
      }

      ::Receipts::Receipt.new(defaults.deep_merge(options))
    end

    def invoice_filename
      "invoice-#{created_at.strftime("%Y-%m-%d")}.pdf"
    end

    def invoice
      invoice_pdf.render
    end

    def invoice_details
      [
        [I18n.t("pay.invoice.number"), id],
        [I18n.t("pay.invoice.date"), I18n.l(created_at, format: :long)],
        [I18n.t("pay.invoice.payment_method"), charged_to]
      ]
    end

    def invoice_pdf(**options)
      defaults = {
        details: invoice_details,
        recipient: [
          customer.customer_name,
          customer.email,
          customer.owner.try(:extra_billing_info)
        ],
        company: {
          name: Pay.business_name,
          address: Pay.business_address,
          email: Pay.support_email,
          logo: Pay.business_logo
        },
        line_items: pdf_line_items
      }

      ::Receipts::Invoice.new(defaults.deep_merge(options))
    end
  end
end
