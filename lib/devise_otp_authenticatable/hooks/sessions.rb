module DeviseOtpAuthenticatable::Hooks
  module Sessions
    extend ActiveSupport::Concern
    include DeviseOtpAuthenticatable::Controllers::UrlHelpers
    include Devise::Controllers::StoreLocation

    included do
      alias_method_chain_redux :create, :otp
    end

    #
    # replaces Devise::SessionsController#create
    #
    def create_with_otp
      resource = warden.authenticate!(auth_options)

      otp_refresh_credentials_for(resource)

      # if otp is enabled
      if otp_challenge_required_on?(resource)
        challenge = resource.generate_otp_challenge!
        devise_stored_location = stored_location_for(resource)
        warden.logout(resource_name)
        session[:otp_return_to] = devise_stored_location
        respond_with resource, :location => otp_credential_path_for(resource, { :challenge => challenge, resource_name => { remember_me: params.dig(resource_name, :remember_me) } })
      # if mandatory, log in user but send him to the must activate otp
      elsif otp_mandatory_on?(resource)
        set_flash_message(:notice, :signed_in_but_otp) if is_navigational_format?
        sign_in(resource_name, resource)
        respond_with resource, location: settings_path("profile", "security")
      # normal sign_in
      else
        set_flash_message(:notice, :signed_in) if is_navigational_format?
        sign_in(resource_name, resource)
        respond_with resource, location: after_sign_in_path_for(resource)
      end
    end


    private

    #
    # resource should be challenged for otp
    #
    def otp_challenge_required_on?(resource)
      return false unless resource.respond_to?(:otp_enabled) && resource.respond_to?(:otp_auth_secret)
      resource.otp_enabled && !is_otp_trusted_device_for?(resource)
    end

    #
    # the resource -should- have otp turned on, but it isn't
    #
    def otp_mandatory_on?(resource)
      return true if resource.class.otp_mandatory
      return false unless resource.respond_to?(:otp_mandatory)

      if resource.is_a? User
        (resource.company_role.present? && resource.company_role.otp_mandatory) && !resource.otp_enabled
      end
    end
  end
end
