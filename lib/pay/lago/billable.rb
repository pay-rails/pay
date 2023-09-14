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
        lago_customer = customer
        pay_subscription = create_placeholder_subscription(name, plan)
        external_id = pay_subscription.to_gid.to_s

        attributes = options.merge(
          external_customer_id: lago_customer.external_id,
          name:, external_id:, plan_code: plan
        )

        begin
          subscription = Lago.client.subscriptions.create(attributes)
        rescue ::Lago::Api::HttpError
          pay_subscription.destroy!
          raise Pay::Lago::Error, e
        end
        
        pay_subscription.update!(processor_id: external_id)
        Pay::Lago::Subscription.sync(external_id, object: subscription)
      end

      def add_payment_method(token = nil, default: true)
        Pay::Lago::PaymentMethod.sync(pay_customer: pay_customer)
      end

      def processor_subscription(subscription_id, options = {})
        Pay::Lago::Subscription.get_subscription(processor_id, subscription_id)
      end

      def trial_end_date(subscription)
        raise Pay::Lago::Error.new("Lago subscriptions do not implement trials.")
      end

      private

      def create_placeholder_subscription(name, plan)
        pay_customer.subscriptions.create!(
          processor_id: ("a".."z").to_a.sample(16).join,
          name:,
          processor_plan: plan,
          quantity: 0,
          status: "incomplete"
        )
      end

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
