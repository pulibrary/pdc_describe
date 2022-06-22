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

  get "works/new-submission", to: "works#new_submission", as: :work_new_submission
  get "works/:id/attachment-select", to: "works#attachment_select", as: :work_attachment_select
  post "works/:id/attachment-select", to: "works#attachment_selected", as: :work_attachment_selected
  get "works/:id/file-upload", to: "works#file_upload", as: :work_file_upload
  get "works/:id/file-cluster", to: "works#file_cluster", as: :work_file_cluster
  get "works/:id/file-other", to: "works#file_other", as: :work_file_other
  get "works/:id/review", to: "works#review"
  post "works/:id/review", to: "works#review"
  post "works/:id/completed", to: "works#completed", as: :work_completed
  post "work/:id/approve", to: "works#approve", as: :approve_work
  post "work/:id/withdraw", to: "works#withdraw", as: :withdraw_work
  post "work/:id/resubmit", to: "works#resubmit", as: :resubmit_work
  get "works/:id/datacite", to: "works#datacite", as: :dataset_work
  resources :works

  delete "collections/:id/:uid", to: "collections#delete_user_from_collection", as: :delete_user_from_collection
  post "collections/:id/add-submitter/:uid", to: "collections#add_submitter", as: :add_submitter
  post "collections/:id/add-admin/:uid", to: "collections#add_admin", as: :add_admin
  resources :collections

  # Anything still unmatched by the end of the routes file should go to the not_found page
  # match '*a', to: redirect('/404'), via: :get
end
