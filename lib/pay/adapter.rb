module Pay
  module Adapter
    extend ActiveSupport::Concern

    def self.current_adapter
      if ActiveRecord::Base.respond_to?(:connection_db_config)
        ActiveRecord::Base.connection_db_config.adapter
      else
        ActiveRecord::Base.connection_config[:adapter]
      end
    end
  end
end
