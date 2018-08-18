module Pay
  class Engine < ::Rails::Engine
    isolate_namespace Pay

    config.autoload_paths += Dir["#{config.root}/lib/**/"]
  end
end
