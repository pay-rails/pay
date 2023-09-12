module Pay
  module Lago
    class Billable
      require 'uri'
      include Lago

      attr_reader :pay_customer

      delegate :processor_id,
        :processor_id?,
        :email,
        :customer_name,
        :card_token,
        to: :pay_customer

      def initialize(pay_customer)
        @pay_customer = pay_customer
      end

      def escaped_processor_id
        return "" unless processor_id?
        URI.encode_www_form_component processor_id
      end

      # Returns a hash of attributes for the Stripe::Customer object
      def customer_attributes
        owner = pay_customer.owner
        gid = pay_customer.to_gid.to_s

        attributes = case owner.class.pay_lago_customer_attributes
        when Symbol
          owner.send(owner.class.pay_lago_customer_attributes, pay_customer)
        when Proc
          owner.class.pay_lago_customer_attributes.call(pay_customer)
        end

        # Guard against attributes being returned nil
        attributes ||= {}

        {external_id: gid, email: email, name: customer_name}.merge(attributes)
      end

      def customer
        if processor_id?
          Lago.client.customers.get(escaped_processor_id)
        else
          lc = Lago.client.customers.create(customer_attributes)
          pay_customer.update!(processor_id: lc.external_id)
          lc
        end
      rescue ::Lago::Api::HttpError => e
        raise Pay::Lago::Error, e
      end

      def update_customer!(**attributes)
        new_attributes = Lago.openstruct_to_h(customer).except(:lago_id)
        Lago.client.customers.create(
          new_attributes.merge(attributes.except(:external_id))
        )
      end

      def charge(amount, addon: nil, options: {})
        processor_id? ? nil : customer
        lago_addon = addon.is_a?(String) ? Lago.client.add_ons.get(addon) : pay_default_addon

        attributes = {
          external_customer_id: processor_id,
          currency: options[:currency] || lago_addon.amount_currency,
          fees: [
            {
              add_on_code: lago_addon.code,
              unit_amount_cents: amount
            }.merge(options.except(:amount_cents, :add_on_code, :currency))
          ]
        }

        invoice = Lago.client.invoices.create(attributes)
        Pay::Lago::Charge.sync(invoice.lago_id, object: invoice)
      rescue ::Lago::Api::HttpError => e
        raise Pay::Lago::Error, e
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        # Make to generate a processor_id
        customer
        attributes = options.merge(
          processor_id: NanoId.generate,
          name: name,
          processor_plan: plan,
          status: :active,
          quantity: options.fetch(:quantity, 1)
        )

        if (trial_period_days = attributes.delete(:trial_period_days))
          attributes[:trial_ends_at] = trial_period_days.to_i.days.from_now
        end

        attributes.delete(:promotion_code)

        pay_customer.subscriptions.create!(attributes)
      end

      def add_payment_method(payment_method_id, default: false)
        # Make to generate a processor_id
        customer

        pay_payment_method = pay_customer.payment_methods.create!(
          processor_id: NanoId.generate,
          default: default,
          type: :card,
          data: {
            brand: "Fake",
            last4: 1234,
            exp_month: Date.today.month,
            exp_year: Date.today.year
          }
        )

        pay_customer.reload_default_payment_method if default
        pay_payment_method
      end

      def processor_subscription(subscription_id, options = {})
        pay_customer.subscriptions.find_by(processor_id: subscription_id)
      end

      def trial_end_date(subscription)
        Date.today
      end

      private

      def pay_default_addon
        begin
          return Lago.client.add_ons.get('pay_default_addon')
        rescue ::Lago::Api::HttpError
          return Lago.client.add_ons.create(
            name: 'Default Charge',
            code: 'pay_default_addon',
            amount_cents: 100,
            amount_currency: 'USD'
          )
        end
      rescue ::Lago::Api::HttpError => e
        raise Pay::Lago::Error, e
      end
    end
  end
end
