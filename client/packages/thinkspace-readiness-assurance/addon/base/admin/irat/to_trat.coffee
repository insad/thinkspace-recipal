import ember from 'ember'
import base  from 'thinkspace-readiness-assurance/base/admin/component'

export default base.extend

  has_errors: ember.computed 'irad.errors.length', 'trad.errors.length', 'selected_send', ->
    @get('selected_send') == true and ( ember.isPresent(@irad.errors) or ember.isPresent(@trad.errors) )

  init: ->
    @_super()
    @irad = @am.rad(name: 'IRAT')
    @trad = @am.rad(name: 'TRAT', width_selector: '.ts-ra_admin-irat-to-trat-content')

  willInsertElement: ->
    @am.get_trat_team_users().then (team_users) =>
      @setup(team_users)
      @set_ready_on()

  setup: (team_users) ->
    @irad.set_team_users(team_users)
    @trad.set_team_users(team_users)
    @irad.set 'due_at_max', 10
    @irad.set 'due_at_interval', 5
    @trad.set 'due_at_max', 10
    @trad.set 'due_at_interval', 5

  actions:
    validate:        -> @validate_data()
    send_transition: -> @send_transition()

  send_transition: ->
    @validate_data()
    @selected_send_on()
    return if @get('has_errors')
    @set_timer()
    irat = @irad.get_data()
    trat = @trad.get_data()
    @am.send_irat_to_trat({irat, trat})
    # @send 'done'

  set_timer: ->
    return if @irad.get('transition_now') == true
    timer = @irad.get_timer()
    if ember.isPresent(timer)
      settings = timer.settings
      if ember.isPresent(settings)
        msg = @irad.get_timer_message()
        timer.settings.message = msg if ember.isPresent(msg)
    else
      settings = {type: 'once', unit: @irad.get('timer_unit')}
      @irad.set_timer({settings})

  # ###
  # ### Validate Due Ats.
  # ###

  # TODO: Verify timer start and end dates.
  validate_data: ->
    @irad.clear_errors()
    @trad.clear_errors()
    @trad.error 'You have not selected any teams.' if ember.isBlank @trad.get_teams()
    irat_due_at = @irad.get('due_at')
    if ember.isBlank(irat_due_at)
      @irad.error 'You have not selected an IRAT due at time'
      return
    else
      if irat_due_at <= new Date()
        @irad.error 'The IRAT due at time is in the past.'
    trat_due_at = @trad.get('due_at')
    if ember.isPresent(trat_due_at)
      @trad.error('TRAT due at time must be greater than IRAT due at time.') if irat_due_at >= trat_due_at
