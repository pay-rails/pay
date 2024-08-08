<<<<<<< Updated upstream
# app/services/lemon_squeezy_service.rb
require 'net/http'
require 'json'

class LemonSqueezyService
  def initialize(api_key)
    @api_key = api_key
  end

  def create_checkout_session(params)
    uri = URI('https://api.lemonsqueezy.com/v1/checkouts')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.request_uri, request_headers)
    request.body = {
      data: {
        type: 'checkouts',
        attributes: {
          product_options: {
            redirect_url: params.dig(:attributes, :redirect_url)
          }
        },
        relationships: {
          store: {
            data: {
              type: 'stores',
              id: params.dig(:relationships, :store, :id)
            }
          },
          variant: {
            data: {
              type: 'variants',
              id: params.dig(:relationships, :variant, :id)
            }
          }
        }
      }
    }.to_json

    response = http.request(request)
    parsed_response = JSON.parse(response.body, symbolize_names: true)

    if response.is_a?(Net::HTTPSuccess)
      {
        success: true,
        checkout_url: parsed_response.dig(:data, :links, :self)
      }
    else
      {
        success: false,
        error: parsed_response[:errors]
      }
    end
  end

  private

  def request_headers
    {
      'Accept' => 'application/vnd.api+json',
      'Content-Type' => 'application/vnd.api+json',
      'Authorization' => "Bearer #{@api_key}"
    }
  end
end
=======
class LemonSqueezyService
    BASE_URL = 'https://api.lemonsqueezy.com'
  
    def initialize(api_key)
      @api_key = api_key
    end
  
    def create_fake_payment(params)
      response = Faraday.post("#{BASE_URL}/payments") do |req|
        req.headers['Authorization'] = "Bearer #{@api_key}"
        req.headers['Content-Type'] = 'application/json'
        req.body = params.to_json
      end
  
      JSON.parse(response.body)
    rescue Faraday::Error => e
      { error: e.message }
    end
  end
>>>>>>> Stashed changes
