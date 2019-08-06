module Thinkspace; module Authorization
class ThinkspaceCommon < ::Totem::Settings.authorization.platforms.thinkspace.cancan.classes.ability_engine

  def process; call_private_methods; end

  protected

  def read_space;  {id: read_space_ids}.merge(read_states); end
  def admin_space; {id: admin_space_ids}.merge(admin_states); end

  def with_read_space_ids;  {space_id: read_space_ids}; end
  def with_admin_space_ids; {space_id: admin_space_ids}; end

  def read_space_association;  {thinkspace_common_spaces: read_space}; end
  def admin_space_association; {thinkspace_common_spaces: admin_space}; end

  def read_states;  {state: ['active']}; end
  def admin_states; {state: ['active', 'inactive']}; end

  private

  def domain
    can [:read], Thinkspace::Common::SpaceType
    can [:read], Thinkspace::Common::Configuration
    can [:read], Thinkspace::Common::Component
  end

  def spaces
    space      = Thinkspace::Common::Space
    invitation = Thinkspace::Common::Invitation
    can :read, space, read_space
    can [:create], space
    can [:fetch_status], invitation, {invitable_type: space.name, invitable_id: read_space_ids}
    return unless admin?
    can :read, space, admin_space
    can [:update, :clone, :import, :invite, :roster, :invitations, :teams, :team_sets], space, admin_space
    can [:read, :update, :destroy, :refresh, :resend], invitation, {invitable_type: space.name, invitable_id: admin_space_ids}
    can [:create], invitation
  end

  def space_users
    space_user = Thinkspace::Common::SpaceUser
    can [:read, :update, :destroy, :resend, :inactivate, :activate],  space_user, with_admin_space_ids
    can [:read_space_owners, :view], space_user, with_read_space_ids
  end

  def users
    user           = Thinkspace::Common::User
    password_reset = Thinkspace::Common::PasswordReset
    can [:create, :sign_in, :sign_out, :stay_alive, :validate, :view, :switch, :avatar, :update_tos], user
    can [:update, :add_key, :list_keys], user, {id: current_user.id}
    can [:read], user, {id: current_user.id}
    can [:create, :read, :update], password_reset
    can [:read_space_owners, :read_commenterable], user, read_space_association
    cannot [:select], user
    return unless admin?
    can [:select, :gradebook, :refresh], user, admin_space_association
    can [:read, :select, :refresh], user, { thinkspace_common_spaces: { id: admin_space_ids } }
  end

  def disciplines
    discipline = Thinkspace::Common::Discipline
    can [:read], discipline
  end

  def agreements
    agreement = Thinkspace::Common::Agreement
    can [:read, :latest_for], agreement
  end

  def keys
    key = Thinkspace::Common::Key
    can [:read], key, { thinkspace_common_user_keys: { user_id: current_user.id } }
  end

end; end; end
