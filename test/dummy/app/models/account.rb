class Account < ApplicationRecord
  include Pay::Merchant
end
