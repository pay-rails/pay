class ApplicationController < ActionController::Base
  include CurrentHelper
  protect_from_forgery with: :exception
end
