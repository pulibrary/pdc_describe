# frozen_string_literal: true
Rails.application.routes.draw do

  # Source: https://curationexperts.github.io/recipes/authentication/shibboleth_and_hyrax.html
  devise_for :users, controllers: { omniauth_callbacks: "omniauth_callbacks" }

  # Disable these routes if you are using Devise's
  # database_authenticatable in your development environment.
  unless AuthConfig.use_database_auth?
    devise_scope :user do
      get 'sign_in', to: 'omniauth#new', as: :new_user_session
      post 'sign_in', to: 'omniauth_callbacks#shibboleth', as: :new_session
      get 'sign_out', to: 'devise/sessions#destroy', as: :destroy_user_session
    end
  end

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root to: "welcome#index"
end
