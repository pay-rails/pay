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
          email: Pay.support_email
        },
        line_items: line_items
      )
    end

    def line_items
      line_items = [
        [I18n.t("receipt.date"), created_at.to_s],
        [I18n.t("receipt.account_billed"), "#{owner.name} (#{owner.email})"],
        [I18n.t("receipt.product"), product],
        [I18n.t("receipt.amount"), ActionController::Base.helpers.number_to_currency(amount / 100.0)],
        [I18n.t("receipt.charged_to"), charged_to]
      ]
      line_items << [I18n.t("receipt.additional_info"), owner.extra_billing_info] if owner.extra_billing_info?
      line_items
    end
  end
end
