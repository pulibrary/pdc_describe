# frozen_string_literal: true
Rails.application.routes.draw do
  resources :users, except: [:new, :destroy, :index, :create]
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root to: "welcome#index"

  # Per https://github.com/pulibrary/pul-the-hard-way/blob/main/services/cas.md
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  devise_scope :user do
    get "sign_in", to: "devise/sessions#new", as: :new_user_session
    get "sign_out", to: "devise/sessions#destroy", as: :destroy_user_session
  end

  post "dataset/:id/approve", to: "datasets#approve", as: :approve_dataset
  post "dataset/:id/withdraw", to: "datasets#withdraw", as: :withdraw_dataset
  post "dataset/:id/resubmit", to: "datasets#resubmit", as: :resubmit_dataset
  resources :datasets
  resources :works

  # Anything still unmatched by the end of the routes file should go to the not_found page
  # match '*a', to: redirect('/404'), via: :get
end
