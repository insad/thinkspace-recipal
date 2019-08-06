require 'spreadsheet'

module Thinkspace; module Casespace; module Exporters; class PhaseScore < Thinkspace::Common::Exporters::Base
  attr_reader :caller, :phase, :ownerables

  def initialize(caller, phase, ownerables)
    @caller     = caller
    @phase      = phase
    @ownerables = ownerables.uniq
  end

  def process
    book  = caller.get_book_for_record(phase)
    sheet = caller.find_or_create_worksheet_for_phase(book, phase, 'Scores')
    caller.add_header_to_sheet(sheet, *(get_sheet_header_identifiers), get_sheet_header_score)
    scope = phase.class.where(id: phase.id)
    ownerables.each_with_index do |ownerable, index|
      row_number   = index + 1 # Offset by 1 due to header row
      # TODO: Is it possible to not query every time here?  
      phase_scores = scope.scope_phase_scores_by_ownerable(ownerable)
      raise InvalidScoresLength, "Multiple phase scores [phase_id: #{phase.id}] for a single ownerable #{ownerable.inspect}" if phase_scores.length > 1
      phase_score                  = phase_scores.first
      phase_score.present? ? score = phase_score.score.to_f : score =  0.0
      sheet.update_row row_number, *(get_ownerable_identifiers(ownerable)), score
    end
  end

  class InvalidScoresLength < StandardError; end;

  private

  def get_sheet_header_identifiers; caller.get_sheet_header_identifiers; end
  def get_sheet_header_score; 'Score'; end

  def get_ownerable_identifiers(ownerable); caller.get_ownerable_identifiers(ownerable); end

end; end; end; end
