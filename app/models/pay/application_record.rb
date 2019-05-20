module Pay
  class ApplicationRecord < Mongoid::Document
    self.abstract_class = true
  end
end
