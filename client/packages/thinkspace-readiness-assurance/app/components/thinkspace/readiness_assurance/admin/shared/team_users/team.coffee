import ember from 'ember'
import ns    from 'totem/ns'
import base  from 'thinkspace-readiness-assurance/base/admin/component'

export default base.extend

  selected: ember.computed 'selected_teams.[]', -> @selected_teams.contains(@team)

  collapsed:    ember.observer 'show_all', -> @set_show_users()
  sorted_users: ember.computed -> @sort_users(@users)

  show_users: null

  willInsertElement: -> @set_show_users()

  set_show_users: -> @set 'show_users', @show_all

  actions:
    toggle_show_users: -> @toggleProperty('show_users'); return

    select: -> @sendAction 'select_team', @team

    select_user: (user) -> @sendAction 'select_user', @team, user
