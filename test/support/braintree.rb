# Braintree configuration
Pay.braintree_gateway = Braintree::Gateway.new(
  environment: :sandbox,
  merchant_id: "zyfwpztymjqdcc5g",
  public_key: "5r59rrxhn89npc9n",
  private_key: "00f0df79303e1270881e5feda7788927"
)

logger = Logger.new("/dev/null")
logger.level = Logger::INFO
Pay.braintree_gateway.config.logger = logger
