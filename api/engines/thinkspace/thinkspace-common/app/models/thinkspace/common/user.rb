module Thinkspace
  module Common
    class User < ActiveRecord::Base
      include ::Totem::Settings.module.thinkspace.session_user_model
      include Thinkspace::Common::Avatar
      # ###
      # ### Validations
      # ###

      validates :email, presence: true, uniqueness: { case_sensitive: false }

      # ###
      # ### AASM
      # ###

      include AASM
      aasm column: :state do
        state :inactive, initial: true
        state :active
        event :activate do;   transitions to: :active, after: :after_activate end
        event :deactivate do; transitions to: :inactive, after: :after_deactivate end
      end

      # ###
      # ### Scopes.
      # ###

      def self.scope_active; active; end  # acitve = aasm auto-generated scope

      def self.scope_read
        joins(:thinkspace_common_space_users).
        where(thinkspace_common_space_users: {role: 'read'})
      end

      def self.scope_parent_id_blank;   where(parent_id: nil); end
      def self.scope_parent_id_present; where.not(parent_id: nil); end

      # ###
      # ### Hooks
      # ###

      after_create do
        set_activation_token
        set_activation_expires_at
        save
      end

      # ###
      # ### Methods
      # ###

      def after_activate
        set_activated_at
        save
      end

      def after_deactivate
        reset_activated_at
        save
      end

      def is_activated?; activated_at.present?; end

      def set_activated_at(date=nil);     self.activated_at          = date || DateTime.now;                          end
      def reset_activated_at;             self.activated_at          = nil;                                           end
      def set_activation_token;           self.activation_token      = generate_activation_token;                     end
      def set_activation_expires_at;      self.activation_expires_at = DateTime.now + activation_token_expires_after; end
      def generate_activation_token;      SecureRandom.urlsafe_base64(nil, false);                                    end
      def activation_token_expires_after; 90.days;                                                                    end
      def activation_expired?;            activation_expires_at <= DateTime.now;                                      end
      def refresh_activation;             set_activation_expires_at; save;                                            end
      def username;                       self.email;                                                                 end
      def full_name;                      "#{first_name} #{last_name}";                                               end
      def name;                           full_name;                                                                  end
      def title;                          "#{last_name}, #{first_name}";                                              end
      
      # TODO: implement
      def create_sandbox
        puts "TODO: Implement user.create_sandbox"
      end

      # ### Terms
      def tos_current
        tos_type      = 'terms_of_service'
        terms         = Thinkspace::Common::Agreement.where("doc_type = ? and effective_at IS NOT NULL", tos_type).order('effective_at')
        current_terms = terms.last
        return false unless terms_accepted_at.present?
        return false unless current_terms.present?
        terms_accepted_at >= current_terms.effective_at ? true : false
      end
        
      # ### Avatar
      def get_default_avatar_path; '/assets/images/_default_user.png'; end

      # ### Keys
      def has_key?; has_key; end
      def has_key
        keys = thinkspace_common_keys.where('expires_at >= ?', Time.now)
        keys.present?
      end
      # ### Scoped attributes
      # def profile(scope)
      #   return {} unless self == scope.current_user
      #   configuration = thinkspace_common_configuration
      #   return {} unless configuration.present?
      #   configuration.settings
      # end

      # def profile_has_role?(role)
      #   configuration = thinkspace_common_configuration
      #   return nil unless configuration.present?
      #   settings = configuration.settings.with_indifferent_access
      #   return nil unless settings.has_key?(:roles)
      #   settings[:roles].include?(role)
      # end

      # ### Callbacks
      def callback_new_api_session; self.touch(:last_sign_in_at); end

      totem_associations
    end
  end
end
