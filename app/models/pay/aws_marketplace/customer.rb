module Pay
  module AwsMarketplace
    class Customer < Pay::Customer
      has_many :charges, dependent: :destroy, class_name: "Pay::AwsMarketplace::Charge"
      has_many :subscriptions, dependent: :destroy, class_name: "Pay::AwsMarketplace::Subscription"
      has_many :payment_methods, dependent: :destroy, class_name: "Pay::AwsMarketplace::PaymentMethod"
      has_one :default_payment_method, -> { where(default: true) }, class_name: "Pay::AwsMarketplace::PaymentMethod"

      store_accessor :data, :aws_account_id

      def api_record
        {customer_identifier: processor_id, customer_aws_account_id: aws_account_id}.compact
      end

      def update_api_record(**attributes)
        raise UpdateError, "AWS Marketplace does not allow updating customer information"
      end

      def charge(amount, options = {})
        raise ChargeError, "AWS Marketplace does not support one-off charges"
      end

      def checkout(product_id:)
        URI("https://aws.amazon.com/marketplace/procurement").tap do |url|
          url.query = URI.encode_www_form(productId: product_id)
        end.to_s
      end

      def subscribe(name: Pay.default_product_name, plan: Pay.default_plan_name, **options)
        raise UpdateError
      end

      def add_payment_method(payment_method_id, default: false)
        raise PaymentMethodError
      end
    end
  end
end
