ENV["BRAINTREE_PUBLIC_KEY"] ||= "5r59rrxhn89npc9n"
ENV["BRAINTREE_PRIVATE_KEY"] ||= "00f0df79303e1270881e5feda7788927"
ENV["BRAINTREE_MERCHANT_ID"] ||= "zyfwpztymjqdcc5g"
ENV["BRAINTREE_ENVIRONMENT"] ||= "sandbox"

Pay.setup do |config|
  # For use in the receipt/refund/renewal mailers
  config.business_name = "Business Name"
  config.business_address = "1600 Pennsylvania Avenue NW"
  config.application_name = "My App"
  config.support_email = "helpme@example.com"

end
