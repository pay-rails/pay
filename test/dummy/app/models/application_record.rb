class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  database = ENV.fetch("DB", "postgresql").to_sym
  connects_to database: { writing: database, reading: database }
end
