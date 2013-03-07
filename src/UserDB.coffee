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
    @emit 'log', "Getting user '#{nickname}'"
    @_getOrDie nickname, (err, user) =>
      if err? then user = defaults()
      callback null, user

  markRegistered: (nickname, callback) ->
    @emit 'log', "Marking '#{nickname}' as registered"
    @_getOrDie nickname, (err, user) =>
      if err?
        user = defaults()
        user.isRegistered = true
        @db.set nickname, user, (err) ->
          callback null, not err?
      else
        @db.update nickname, isRegistered: true, (err) ->
          callback null, not err?

  meet: (nickname, callback) ->
    @emit 'log', "Meeting '#{nickname}'"
    @_getOrDie nickname, (err, user) =>
      if err? or not data?.isRegistered
        @emit 'log', "Can't meet '#{nickname}'; not a registered user."
        callback null, false
      else
        @emit 'log', "#{nickname} was granted sudo"
        @db.update nickname, hasSudo: true, (err) ->
          if err? then @emit 'log', "PROBLEM SAVING hasSudo FOR USER #{nickname}"
          callback null, not err?

  forget: (nickname, callback) ->
    @emit 'log', "Forgetting '#{nickname}'"
    @db.remove nickname, (err) ->
      callback err if typeof callback is 'function'

  _getOrDie: (nickname, callback, shallow) ->
    shallow = shallow ? false
    if not @db? then error callback
    else @db.get nickname, callback, shallow


defaults = ->
  return userDefaults =
    isRegistered: false
    hasSudo: false

error = (callback) ->
  callback new Error "User database not available."

module.exports = UserDB
