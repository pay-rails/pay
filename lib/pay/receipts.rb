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
        [I18n.t("pay.receipt.number"), receipt_number],
        [I18n.t("pay.receipt.date"), I18n.l(created_at, format: :long)],
        [I18n.t("pay.receipt.payment_method"), charged_to]
      ]
    end

    def pdf_line_items
      items = [
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
      if line_items.any?
        line_items.each do |li|
          items << [li["description"], li["quantity"], Pay::Currency.format(li["unit_amount"], currency: currency), Pay::Currency.format(li["amount"], currency: currency)]

          Array.wrap(li["discounts"]).each do |discount_id|
            if (discount = total_discount_amounts.find { |d| d.dig("discount", "id") == discount_id })
              items << [discount_description(discount), nil, nil, Pay::Currency.format(-discount["amount"], currency: currency)]
            end
          end
        end
      else
        items << [product, 1, Pay::Currency.format(amount, currency: currency), Pay::Currency.format(amount, currency: currency)]
      end

      # If no subtotal, we will display the total
      items << [nil, nil, I18n.t("pay.line_items.subtotal"), Pay::Currency.format(subtotal || amount, currency: currency)]

      # Discounts on the invoice
      Array.wrap(discounts).each do |discount_id|
        if (discount = total_discount_amounts.find { |d| d.dig("discount", "id") == discount_id })
          items << [nil, nil, discount_description(discount), Pay::Currency.format(-discount["amount"], currency: currency)]
        end
      end

      # Tax rates
      Array.wrap(total_tax_amounts).each do |tax_amount|
        next if tax_amount["amount"].zero?
        items << [nil, nil, tax_description(tax_amount), Pay::Currency.format(tax_amount["amount"], currency: currency)]
      end

      items << [nil, nil, I18n.t("pay.line_items.total"), Pay::Currency.format(amount, currency: currency)]
      items
    end

    def discount_description(discount)
      coupon = discount.dig("discount", "coupon")
      name = coupon.dig("name")

      if (percent = coupon["percent_off"])
        I18n.t("pay.line_items.percent_discount", name: name, percent: ActiveSupport::NumberHelper.number_to_rounded(percent, strip_insignificant_zeros: true))
      else
        I18n.t("pay.line_items.amount_discount", name: name, amount: Pay::Currency.format(coupon["amount_off"], currency: coupon["currency"]))
      end
    end

    def tax_description(tax_amount)
      tax_rate = tax_amount["tax_rate"]
      percent = "#{ActiveSupport::NumberHelper.number_to_rounded(tax_rate["percentage"], strip_insignificant_zeros: true)}%"
      percent += " inclusive" if tax_rate["inclusive"]
      "#{tax_rate["display_name"]} - #{tax_rate["jurisdiction"]} (#{percent})"
    end

    def receipt_line_items
      line_items = pdf_line_items

      # Include total paid
      line_items << [nil, nil, I18n.t("pay.receipt.amount_paid"), Pay::Currency.format(amount, currency: currency)]

      if refunded?
        # If we have a list of individual refunds, add each entry
        if refunds&.any?
          refunds.each do |refund|
            next unless refund["status"] == "succeeded"
            refunded_at = Time.at(refund["created"]).to_date
            line_items << [nil, nil, I18n.t("pay.receipt.refunded_on", date: I18n.l(refunded_at, format: :long)), Pay::Currency.format(refund["amount"], currency: refund["currency"])]
          end
        else
          line_items << [nil, nil, I18n.t("pay.receipt.refunded"), Pay::Currency.format(amount_refunded, currency: currency)]
        end
      end

      line_items
    end

    def receipt_pdf(**options)
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
          email: Pay.support_email.address,
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
        [I18n.t("pay.invoice.number"), invoice_number],
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
          email: Pay.support_email.address,
          logo: Pay.business_logo
        },
        line_items: pdf_line_items
      }

      ::Receipts::Invoice.new(defaults.deep_merge(options))
    end

    def invoice_number
      id
    end

    def receipt_number
      invoice_number
    end
  end
end
