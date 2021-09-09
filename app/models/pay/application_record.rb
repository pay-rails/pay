module Pay
  class ApplicationRecord < Pay.model_parent_class.constantize
    self.abstract_class = true
    self.table_name_prefix = "pay_"

    # Serialize using ActiveRecord::Store when column is text
    def self.ensure_store(name)
      return unless table_exists?
      store name, coder: JSON if attribute_types[name.to_s].type == :text
    end
  end
end
