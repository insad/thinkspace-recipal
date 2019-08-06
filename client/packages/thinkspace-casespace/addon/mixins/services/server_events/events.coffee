import ember       from 'ember'
import ns          from 'totem/ns'
import totem_scope from 'totem/scope'

export default ember.Mixin.create

  handle_server_event: (data, socketio_event) ->
    value = data.value or {}
    event = value.event
    console.info 'casespace received server_event--->', event, data
    switch event
      when 'transition_to_phase'  then @event_transition_to_phase(value, socketio_event)
      when 'phase_states'         then @event_phase_states(value, socketio_event)
      when 'message'              then @event_message(value, socketio_event)

  # ###
  # ### Events.
  # ###

  event_transition_to_phase: (value, socketio_event) ->
    @load_records_into_store(value).then =>
      @change_phase_states(value).then =>
        @transition_to_phase(value.transition_to_phase_id)

  event_phase_states: (value, socketio_event) ->
    @load_records_into_store(value).then =>
      @change_phase_states(value).then =>
        return

  event_message: (data, socketio_event) ->
    console.info 'recevied assignment message:', {data, socketio_event}
    return if ember.isBlank(data)
    rooms      = data.room or data.rooms
    data.rooms = socketio_event if ember.isBlank(rooms)
    @messages.add(data)

  # ###
  # ### Transition to Phase.
  # ###

  transition_to_phase: (phase_id) ->
    return if ember.isBlank(phase_id)
    @find_phase(phase_id).then (phase) =>
      @casespace.transition_to_phase(phase)

  change_phase_states: (value) ->
    new ember.RSVP.Promise (resolve, reject) =>
      return resolve() if ember.isBlank(value)
      @lock_phase_states(value.lock_phase_ids).then =>
        @complete_phase_states(value.complete_phase_ids).then =>
          @unlock_phase_states(value.unlock_phase_ids).then => resolve()

  lock_phase_states:     (ids) -> @update_phase_states('lock', ids)
  unlock_phase_states:   (ids) -> @update_phase_states('unlock', ids)
  complete_phase_states: (ids) -> @update_phase_states('complete', ids)

  update_phase_states: (fn, phase_ids) ->
    new ember.RSVP.Promise (resolve, reject) =>
      return resolve() if ember.isBlank(phase_ids)
      for phase_id in ember.makeArray(phase_ids)
        @get_phase_states(phase_id).then (phase_states) =>
          phase_states.forEach (phase_state) => phase_state[fn]()
          resolve()

  get_phase_states: (phase_id) ->
    new ember.RSVP.Promise (resolve, reject) =>
      return resolve([]) if ember.isBlank(phase_id)
      @find_phase(phase_id).then (phase) =>
        if ember.isPresent(phase)
          resolve @pm.map.get_current_user_phase_states(phase)
        else
          resolve []

  find_phase: (id) -> @find_record(ns.to_p('phase'), id)

