import ember from 'ember'
import base  from 'thinkspace-readiness-assurance/base/ra_component'

export default base.extend

  question_managers: ember.computed ->
    managers = []
    @rm.question_manager_map.forEach (qm) => managers.push(qm)
    managers

  actions:
    chat:       (qid) -> @sendAction 'chat', qid
    chat_close: (qid) -> @sendAction 'chat_close', qid
