# Integration tests for controllers that live in the Pay engine
class EngineIntegrationTest < ActionDispatch::IntegrationTest
  include Pay::Engine.routes.url_helpers

  setup do
    @routes = Pay::Engine.routes
  end
end
