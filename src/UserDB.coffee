tiny = require 'tiny'
events = require 'events'

class UserDB extends events.EventEmitter
  constructor: (filename) ->
    @db = null
    tiny filename, (err, db) =>
      if err?
        @emit 'error', err
      else
        @db = db
        @emit 'load'

  get: (nickname, callback) ->
    log "Getting user '#{nickname}'"
    if not @db? then error callback
    else
      @db.get nickname, (err, user) ->
        if err? then user = defaults()
        callback null, user

  markRegistered: (nickname, callback) ->
    log "Marking '#{nickname}' as registered"
    if not @db? then error callback
    else
      @db.get nickname, (err, user) =>
        if err?
          user = defaults()
          user.isRegistered = true
          @db.set nickname, user, (err) ->
            callback null, not err?
        else
          @db.update nickname, isRegistered: true, (err) ->
            callback null, not err?

  meet: (nickname, callback) ->
    log "Meeting '#{nickname}'"
    if not @db? then error callback
    else
      @db.get nickname, (err, data) =>
        if err? or not data?.isRegistered
          log "Can't meet '#{nickname}'; not a registered user."
          callback null, false
        else
          @db.update nickname, hasSudo: true, (err) ->
            callback null, not err?

  forget: (nickname, callback) ->
    @db.remove nickname, (err) ->
      callback err if typeof callback is 'function'

defaults = ->
  return userDefaults =
    isRegistered: false
    hasSudo: false

log = (args...) ->
  console.log "[UserDB]", args...

error = (callback) ->
  callback new Error "User database not available."

module.exports = UserDB
