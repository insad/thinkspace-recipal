import ember from 'ember'

export default ember.Object.extend
  init: ->
    @_super()
    @set 'guid_properties', []

  get_value: (guid) -> @tvo.get_path_value @_get_path(guid)

  set_value: (value)             -> @_set_value(@tvo.generate_guid(), value)
  set_value_for: (source, value) -> @_set_value(@tvo.guid_for(source), value)

  get_all: -> @_get_guid_properties().map (prop) => @get(prop)

  # ###
  # ### Internal.
  # ###

  _set_value: (guid, value) ->
    path = @_get_path(guid)
    @_get_guid_properties().push(guid)
    @tvo.set_path_value(path, value)
    path

  _get_path: (guid) -> "#{@tvo_property}.#{guid}"

  _get_guid_properties: -> @get('guid_properties')

  toString: -> 'TvoValue'
