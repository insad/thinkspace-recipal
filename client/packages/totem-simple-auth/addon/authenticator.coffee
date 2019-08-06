import ember          from 'ember'
import ns             from 'totem/ns'
import config         from 'totem/config'
import ajax           from 'totem/ajax'
import util           from 'totem/util'
import totem_scope    from 'totem/scope'
import totem_messages from 'totem-messages/messages'
import base           from 'simple-auth/authenticators/base'

export default base.extend

  restore: (data) ->
    console.warn 'authenticator restore', data, ajax.adapter_host()
    new ember.RSVP.Promise (resolve, reject) =>
      return reject() unless (data.token and data.email and data.user_id)

      # Server call to validate the users credentials when a page is refreshed
      # or a browser is opened that was prevously signed in by a user.
      #
      # Performing this in the restore function, allows gracefully rejecting the restore and
      # reloading the application back to the sign in page.
      # Otherwise, if just resolve, the first server call (typically show user) will fail
      # if the session is invalid (e.g. timed out).
      #
      # The credentials (user token, email and user record -> not password) are stored in
      # the browser's local storage and to clear them, the user must 'sign out'.

      # When 'restore' is called, the ember-data store is not intialized yet, so cannot make
      # a store/model request so need the full validate user url.

      validate_user_url = config.simple_auth and config.simple_auth.validate_user_url

      return reject() unless validate_user_url

      if util.starts_with(validate_user_url, 'http')
        url = validate_user_url
      else
        url = ajax.adapter_host()
        return reject() unless url
        url += '/'  unless ( util.ends_with(url, '/') or util.starts_with(validate_user_url, '/') )
        url += validate_user_url

      query =
        url:  url
        data: {user_id: data.user_id}
        beforeSend: (jqXHR) =>
          # Simulate the authorizer's jquery Prefilter by adding the Authorization header
          # with the token and email values (e.g. simple-auth-devise authorizer).
          auth = 'token' + '="' + data.token + '", ' + 'email' + '="' + data.email + '"'
          jqXHR.setRequestHeader('Authorization', 'Token ' + auth)
        success: (payload) =>
          store    = @get_store()
          type     = ns.to_p('user')
          metadata = ns.to_p('metadata')
          user     = store.push(type, store.normalize(type, payload[type]))
          totem_scope.set_current_user(user)
          store.pushMany(metadata, store.normalize(metadata, payload[metadata])) if payload[metadata]
          
          resolve(data)
        error: (error) =>
          reject()

      ember.$.ajax(query)

  authenticate: (options) ->
    totem_messages.clear_all()

    new ember.RSVP.Promise (resolve, reject) =>
      query =
        model:        ns.to_p('user')
        verb:         'post'
        action:       'sign_in'
        data:         options
        skip_message: true

      store       = @get_store()
      local_store = @get_local_store()
      return reject('totem_simple_auth authenticate store is blank.') unless store
      return reject('totem_simple_auth authenticate local store is blank.') unless local_store

      #local_store.clear() # If this is left in, this clears other browsers that are already logged in.
      local_store.set('isAuthenticated', false) # Without this, a new window will not trigger the redirect after route.

      ajax.object(query).then (payload) =>
        type     = ns.to_p('user')
        metadata = ns.to_p('metadata')
        user     = store.push(type, store.normalize(type, payload[type]))
        totem_scope.set_current_user(user)
        store.pushMany(metadata, store.normalize(metadata, payload[metadata])) if payload[metadata]

        resolve
          token:            payload.token
          email:            user.get('email')
          user_id:          user.get('id')
          # for switch user capability:
          switch_user:      false
          original_user:    true
          original_user_id: user.get('id')
      , (error) =>
        reject(error)

  invalidate: (data) ->
    console.warn 'authenticator invalidate', data
    # return ember.RSVP.resolve()  # do nothing
    new ember.RSVP.Promise (resolve, reject) =>
      query =
        model:        ns.to_p('user')
        verb:         'post'
        action:       'sign_out'
        skip_message: true
      ajax.object(query).then (payload) =>
        resolve()
      , (error) =>
        resolve()  # if the server returns an error, still sign out the ember user to clear the stores e.g. resolve not reject

  get_store: ->
    container = ajax.get_container()
    return null unless container
    container.lookup('store:main')

  get_local_store: ->
    container = ajax.get_container()
    return null unless container
    container.lookup('simple-auth-session:main')
