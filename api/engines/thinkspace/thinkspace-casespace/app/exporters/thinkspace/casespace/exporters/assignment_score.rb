require 'spreadsheet'

module Thinkspace; module Casespace; module Exporters; class AssignmentScore < Thinkspace::Common::Exporters::Base
  attr_reader :caller, :assignment, :ownerables, :phase_class, :team_class, :user_class

  def initialize(caller, assignment, ownerables)
    @caller      = caller
    @assignment  = assignment
    @ownerables  = ownerables.order(:last_name).uniq # TODO: Why does this error?
    @phase_class = Thinkspace::Casespace::Phase
    @team_class  = Thinkspace::Team::Team
    @user_class  = Thinkspace::Common::User
  end

  def process
    book   = caller.get_book_for_record(assignment)
    sheet  = caller.find_or_create_worksheet_for_assignment(book, assignment, 'Total Scores')
    phases = assignment.thinkspace_casespace_phases.order(:position)
    titles = phases.pluck(:title)
    caller.add_header_to_sheet(sheet, *(get_sheet_header_identifiers), *titles, 'Total')
    # Ownerables is [User, User,...]
    ownerables.each_with_index do |ownerable, index|
      row        = Array.new
      row_number = index + 1 # Offset by 1 due to header row
      phases.each do |phase|
        phase.is_team_based? ? score = get_team_score(phase, ownerable) : score = get_ownerable_score(phase, ownerable)
        row.push score
      end
      row.push get_total(row) # Add total at end.
      row.unshift *(get_ownerable_identifiers(ownerable)) # Add email at beginning
      sheet.insert_row row_number, row
    end
  end

  def get_total(row)
    row.inject(0.0) { |sum, x| sum + x }
  end

  def get_team_score(phase, ownerable)
    phase_teams                  = team_class.users_teams(phase, ownerable)
    assignment_teams             = team_class.users_teams(@assignment, ownerable)
    phase_teams.present? ? teams = phase_teams : teams = assignment_teams
    raise InvalidTeamsLength, "Multiple teams for [phase_id: #{phase.id}] for ownerable: #{ownerable.inspect}" if teams.length > 1
    team = teams.first
    team.present? ? get_ownerable_score(phase, team) : 0.0
  end

  def get_ownerable_score(phase, ownerable)
    phase_scores = phase_class.where(id: phase.id).scope_phase_scores_by_ownerable(ownerable)
    if phase_scores.length > 1
      uniq_scores   = phase_scores.pluck(:score).uniq
      highest_score = phase_scores.order(:score).last
      last_created  = phase_scores.order(:created_at).last        
      raise InvalidScoresLength, "Multiple phase scores [phase_id: #{phase.id}] for a single ownerable #{ownerable.inspect}" if uniq_scores.length > 1 && highest_score != last_created
      phase_score   = highest_score
    else
      phase_score = phase_scores.first
    end
    phase_score.present? ? phase_score.score.to_f : 0.0
  end

  class InvalidScoresLength < StandardError; end;

  private

  def get_sheet_header_identifiers; caller.get_sheet_header_identifiers(user_class.name); end

  def get_ownerable_identifiers(ownerable); caller.get_ownerable_identifiers(ownerable); end

end; end; end; end
