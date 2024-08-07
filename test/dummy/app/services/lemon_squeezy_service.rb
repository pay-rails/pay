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