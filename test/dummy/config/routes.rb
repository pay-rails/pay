# frozen_string_literals: true

Rails.application.routes.draw do
  namespace :braintree do
    resources :subscriptions do
      member do
        patch :cancel
        patch :resume
      end
    end
    resources :charges do
      member do
        patch :refund
      end
    end
  end

  namespace :stripe do
    resources :subscriptions do
      member do
        patch :cancel
        patch :resume
      end
    end
    resources :charges do
      member do
        patch :refund
      end
    end

    namespace :charges do
      resource :import
    end
  end

  root to: "main#show"
end
