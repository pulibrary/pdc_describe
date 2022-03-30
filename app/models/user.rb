# frozen_string_literal: true

class User < ApplicationRecord

  # Reference: https://curationexperts.github.io/recipes/authentication/shibboleth_and_hyrax.html
  # Include devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  # remove :database_authenticatable in production, remove :validatable to integrate with Shibboleth
  devise_modules = [:omniauthable, :rememberable, :trackable, omniauth_providers: [:shibboleth], authentication_keys: [:uid]]
  devise_modules.prepend(:database_authenticatable) if AuthConfig.use_database_auth?
  devise(*devise_modules)

  def self.from_omniauth(auth)
    # Uncomment to capture what a shib auth object looks like for testing
    # Rails.logger.debug "auth = #{auth.inspect}"
    user = where(provider: auth.provider, uid: auth.info.uid).first_or_create
    user.name = auth.info.display_name
    user.uid = auth.info.uid
    user.email = auth.info.mail
    user.save
    user
  end
end
