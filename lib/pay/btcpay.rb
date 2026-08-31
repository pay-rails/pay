module Pay
  module Btcpay
    extend self

    # Configuration for BTCPay Server
    def configure
      yield self
    end

    class << self
      attr_accessor :api_url, :api_key, :store_id
    end

    # Get API client instance
    def client
      @client ||= Client.new(api_url: api_url, api_key: api_key, store_id: store_id)
    end

    # HTTP client for BTCPay API
    class Client
      require 'net/http'
      require 'json'

      def initialize(api_url:, api_key:, store_id:)
        @api_url = api_url.to_s.chomp('/')
        @api_key = api_key
        @store_id = store_id
      end

      # Create an invoice
      def create_invoice(params)
        post("/stores/#{@store_id}/invoices", params)
      end

      # Get invoice details
      def get_invoice(invoice_id)
        get("/stores/#{@store_id}/invoices/#{invoice_id}")
      end

      # Create a payment request (for recurring payments)
      def create_payment_request(params)
        post("/stores/#{@store_id}/payment-requests", params)
      end

      # Get payment request details
      def get_payment_request(request_id)
        get("/stores/#{@store_id}/payment-requests/#{request_id}")
      end

      # Update payment request
      def update_payment_request(request_id, params)
        put("/stores/#{@store_id}/payment-requests/#{request_id}", params)
      end

      # Create webhook subscription
      def create_webhook(params)
        post("/stores/#{@store_id}/webhooks", params)
      end

      # Get webhook
      def get_webhook(webhook_id)
        get("/stores/#{@store_id}/webhooks/#{webhook_id}")
      end

      # Redeliver webhook
      def redeliver_webhook(webhook_id, delivery_id)
        post("/stores/#{@store_id}/webhooks/#{webhook_id}/deliveries/#{delivery_id}/redeliver", {})
      end

      private

      def get(path, params = {})
        request(:get, path, params)
      end

      def post(path, params = {})
        request(:post, path, params)
      end

      def put(path, params = {})
        request(:put, path, params)
      end

      def request(method, path, params)
        uri = URI("#{@api_url}#{path}")
        uri.query = URI.encode_www_form(params) if method == :get && params.any?

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = 30

        request_obj = case method
                      when :get
                        Net::HTTP::Get.new(uri)
                      when :post
                        req = Net::HTTP::Post.new(uri)
                        req.body = JSON.generate(params) if params.any?
                        req
                      when :put
                        req = Net::HTTP::Put.new(uri)
                        req.body = JSON.generate(params) if params.any?
                        req
                      end

        request_obj['Authorization'] = "token #{@api_key}"
        request_obj['Content-Type'] = 'application/json'

        response = http.request(request_obj)

        case response.code.to_i
        when 200..299
          JSON.parse(response.body) if response.body.to_s.strip.length > 0
        else
          raise "BTCPay API Error: #{response.code} - #{response.body}"
        end
      end
    end
  end
end
