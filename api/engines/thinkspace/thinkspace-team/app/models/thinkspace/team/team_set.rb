module Thinkspace
  module Team
    class TeamSet < ActiveRecord::Base    
      # ### State Machine
      include AASM

      aasm column: :state do
        state :neutral, initial: true
        state :locked
        event :lock do
          transitions to: :locked
        end
      end

      # ### Serialized Attributes
      def metadata(scope); get_metadata(scope); end
      def get_metadata(scope)
        hash                    = Hash.new
        hash[:total_teams]      = Thinkspace::Team::TeamSet.scope_unlocked_teams(self).count
        hash[:unassigned_users] = unassigned_user_count
        hash
      end

      # ### Helpers
      def authable; thinkspace_common_space; end
      def get_space; thinkspace_common_space; end

      def assign_to_record(record, unassign=true)
        self.class.unassign_all_from_record(record) if unassign
        record.thinkspace_team_team_set_teamables << Thinkspace::Team::TeamSetTeamable.create(thinkspace_team_team_set: self)
      end

      def self.unassign_all_from_record(record)
        record.thinkspace_team_team_set_teamables.destroy_all
      end

      def unassigned_user_count
        user_count = authable.thinkspace_common_users.count
        teams      = Thinkspace::Team::TeamSet.scope_unlocked_teams(self).includes(:thinkspace_common_users)
        user_ids   = []
        teams.each do |team|
          team.thinkspace_common_users.pluck(:id).each do |id|
            user_ids << id
          end
        end
        user_ids.uniq!
        user_count - user_ids.length
      end

      def self.scope_unlocked_teams(team_set)
        team_set.thinkspace_team_teams.where.not(state: Thinkspace::Team::Team.state_locked)
      end

      # ### Cloning
      include ::Totem::Settings.module.thinkspace.deep_clone_helper

      def cyclone(options={})
        self.transaction do
          title                 = options[:title]
          cloned_team_set       = clone_self(options)
          cloned_team_set.title = title if title.present?
          clone_save_record(cloned_team_set)
          options[:team_set] = cloned_team_set
          options[:authable] = options[:authable] || get_space
          options.delete(:title) if options.has_key?(:title) # Do not carry the Team Set title into the team.
          self.thinkspace_team_teams.each do |team|
            team.cyclone(options)
          end
          cloned_team_set
        end
      end

      def clone_and_lock(authable, options={})
        time     = Time.now.strftime('%D %r')
        title    = "#{self.title} - #{time}"
        team_set = self.cyclone(authable: authable, title: title)
        team_set.lock!
        team_set
      end

      def add_teamables(teamables)
        teamables = Array.wrap(teamables)
        teamables.each do |teamable|
          self.thinkspace_team_team_set_teamables << Thinkspace::Team::TeamSetTeamable.new(teamable: teamable)
        end
      end

      def unlocked_teams
        thinkspace_team_teams.where.not(state: Thinkspace::Team::Team.state_locked)
      end

      totem_associations
    end
 end
end