# frozen_string_literal: true

require "sidekiq/web"

Rails.application.routes.draw do
  resources :work_activity_notifications, only: [:index, :show]

  mount Sidekiq::Web => "/sidekiq" # mount Sidekiq::Web in your Rails app
  mount HealthMonitor::Engine, at: "/"

  # This route is to handle user ids that are in the form abc@something.com because
  # Rails (understandably) does not like the ".com" in the URL
  get "users/:id.:format/edit", to: "users#edit"

  resources :users, except: [:new, :destroy, :create]
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root to: "welcome#index"

  # Per https://github.com/pulibrary/pul-the-hard-way/blob/main/services/cas.md
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  devise_scope :user do
    get "sign_in", to: "devise/sessions#new", as: :new_user_session
    get "sign_out", to: "devise/sessions#destroy", as: :destroy_user_session
  end

  get "about", to: "welcome#about", as: :welcome_about
  get "license", to: "welcome#license", as: :welcome_license
  get "how-to-submit", to: "welcome#how_to_submit", as: :welcome_how_to_submit

  # The work wizard
  get "works/new-submission", to: "works_wizard#new_submission", as: :work_create_new_submission
  post "works/new-submission", to: "works_wizard#new_submission_save", as: :work_new_submission
  get "works/:id/readme-select", to: "works_wizard#readme_select", as: :work_readme_select
  patch "works/:id/readme-uploaded", to: "works_wizard#readme_uploaded", as: :work_readme_uploaded
  patch "works/:id/file-upload", to: "works_wizard#file_uploaded", as: :work_file_uploaded
  get "works/:id/file-upload", to: "works_wizard#file_upload", as: :work_file_upload
  patch "works/:id/update-wizard", to: "works_wizard#update_wizard", as: :update_work_wizard
  get "works/:id/edit-wizard", to: "works_wizard#edit_wizard", as: :edit_work_wizard
  get "works/:id/file-other", to: "works_wizard#file_other", as: :work_file_other
  get "works/:id/review", to: "works_wizard#review", as: :work_review
  post "works/:id/review", to: "works_wizard#review"
  post "works/:id/validate", to: "works_wizard#validate", as: :work_validate
  get "works/:id/attachment-select", to: "works_wizard#attachment_select", as: :work_attachment_select
  post "works/:id/attachment-select", to: "works_wizard#attachment_selected", as: :work_attachment_selected

  get "works/:id/file-list", to: "works#file_list", as: :work_file_list
  post "work/:id/approve", to: "works#approve", as: :approve_work
  post "work/:id/withdraw", to: "works#withdraw", as: :withdraw_work
  post "work/:id/resubmit", to: "works#resubmit", as: :resubmit_work
  post "work/:id/add-message", to: "works#add_message", as: :add_message_work
  post "work/:id/add-provenance-note", to: "works#add_provenance_note", as: :add_provenance_note
  put "works/:id/assign-curator/:uid", to: "works#assign_curator", as: :work_assign_curator
  get "works/:id/datacite", to: "works#datacite", as: :datacite_work
  get "works/:id/datacite/validate", to: "works#datacite_validate", as: :datacite_validate_work
  get "works/:id/download", controller: "work_downloader", action: "download", as: :work_download
  post "works/:id/migrate_content", controller: "work_migration", action: "migrate", as: :work_migrate_content
  get "works/:id/bibtex" => "works#bibtex", as: :work_bibtex
  resources :works
  get "/doi/*doi", to: "works#resolve_doi", as: :resolve_doi, format: false
  get "/ark/*ark", to: "works#resolve_ark", as: :resolve_ark, format: false

  get "upload-snapshots/:work_id", to: "upload_snapshots#edit", as: :edit_upload_snapshot
  get "upload-snapshots/:id/download", to: "upload_snapshots#download", as: :download_upload_snapshot
  post "upload-snapshots", to: "upload_snapshots#create", as: :create_upload_snapshot
  delete "upload-snapshots/:id", to: "upload_snapshots#destroy", as: :delete_upload_snapshot

  delete "groups/:id/:uid", to: "groups#delete_user_from_group", as: :delete_user_from_group
  post "groups/:id/add-submitter/:uid", to: "groups#add_submitter", as: :add_submitter
  post "groups/:id/add-admin/:uid", to: "groups#add_admin", as: :add_admin
  resources :groups

  get "/collections/:id", to: redirect("/groups/%{id}"), as: :collections
  get "/reports/dataset-list", to: "reports#dataset_list", as: :reports_dataset_list

  # Anything still unmatched by the end of the routes file should go to the not_found page
  # match '*a', to: redirect('/404'), via: :get
end
