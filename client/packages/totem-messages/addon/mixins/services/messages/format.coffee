import ember from 'ember'

export default ember.Mixin.create

  format_pre: (item) ->
    message  = @format_item(item)
    parts    = []
    parts.push ('To Users: ' + message.to_users) if ember.isPresent(message.to_users)
    parts.push ('To Teams: ' + message.to_teams) if ember.isPresent(message.to_teams)
    parts.push message.body
    parts.join('\n')

  format_item: (item) ->
    to_users = item.get('to_users')
    to_teams = item.get('to_teams')
    body     = item.get('body')
    to_users = @format_to_users(to_users) if ember.isPresent(to_users)
    to_teams = @format_to_teams(to_teams) if ember.isPresent(to_teams)
    body     = @format_body(body)
    {to_users, to_teams, body}

  format_to_users: (users) -> @format_titles_to_string(users)

  format_to_teams: (teams) -> @format_titles_to_string(teams)

  format_body: (body) -> body

  format_titles_to_string: (value) ->
    values = ember.makeArray(value).compact().mapBy 'title'
    values.sort().join('; ')

  format_users_and_teams: (users, teams) ->
    values = users.copy()
    values.push(teams...)
    @format_titles_to_string(values)
