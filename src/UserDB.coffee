tiny = require 'tiny'
events = require 'events'
regex = require './regex'

createUpdatePropertyFunc = (property) ->
  return (nickname, value, callback) ->
    @emit 'debug', "Setting #{property} for '#{nickname}' to #{value}."
    @_getOrDie nickname, (err, user) =>
      if err?
        user = createDefaultUser()
        user.nickname = nickname
        user[property] = value
        @db.set nickname, user, (err) ->
          if err? then callback new Error "Can't create user '#{nickname}' with #{property} set to #{value}."
          else callback null
      else
        update = {}
        update[property] = value
        @db.update nickname, update, (err) ->
          if err? then callback new Error "Can't set #{property} to #{value} for user '#{nickname}'."
          else callback null


class UserDB extends events.EventEmitter
  constructor: (filename, @bot) ->
    @db = null
    tiny filename, (err, db) =>
      if err?
        process.nextTick => @emit 'error', err
      else
        @db = db
        db.compact =>
          each = (doc) ->
            if doc.isRegistered or not doc.chanOp? or doc.chanOp.length > 0
              db.update doc.nickname, isRegistered:false, chanOp:[], (err) ->
          done = =>
            process.nextTick => @emit 'load', 'cookies'
          db.each each, done

  get: (nickname, callback) ->
    @emit 'debug', "Getting user '#{nickname}'"
    @_getOrDie nickname, (err, user) =>
      if err? then user = createDefaultUser()
      bot = @bot
      user.is = (role, arg) ->
        cb = if typeof arg is 'function' then arg else ->
        if role is 'op'
          if typeof arg isnt 'string'
            throw new Error 'No channel specified.'
          return @chanOp? and arg in @chanOp
        if role is 'registered'
          if @isRegistered then cb true
          else bot.checkNickServ nickname, cb
        if role is 'admin'
          if @isAdmin
            @is 'registered', (isRegistered) =>
              cb isRegistered and @isAdmin
          else cb false

      callback null, user

  forget: (nickname, callback) ->
    @emit 'debug', "Forgetting '#{nickname}'"
    @db.remove nickname, (err) ->
      callback err if typeof callback is 'function'

  setChanOp: (channel, nickname, op, callback) ->
    if typeof callback isnt 'function' then callback = (err) -> #ignore
    @emit 'debug', "Setting #{if op then '-' else '+'}@ for #{nickname} in #{channel}."
    @_getOrDie nickname, (err, user) =>
      if not err?
        if !op and user.chanOp? and channel in user.chanOp
          # Shouldn't be chanOp but is - remove.
          user.chanOp.splice user.chanOp.indexOf(channel), 1
          updateNeeded = true
        else if op and channel not in user.chanOp
          if user.chanOp? and user.chanOp.length > 0
            user.chanOp.push channel
          else
            user.chanOp = [channel]
          updateNeeded = true

        if updateNeeded
          @db.update nickname, chanOp: user.chanOp, callback
        else
          callback null
      else if op
        user = createDefaultUser()
        user.nickname = nickname
        user.chanOp = [channel]
        @db.set nickname, user, callback
      else
        callback null
      return

  setIsRegistered: createUpdatePropertyFunc 'isRegistered'

  setIsAdmin:  createUpdatePropertyFunc 'isAdmin'

  _getOrDie: (nickname, callback, shallow) ->
    shallow = shallow ? false
    if not @db? then callback new Error 'User database not available.'
    else @db.get nickname, callback, shallow

createDefaultUser = ->
  return userDefaults =
    isRegistered: false
    isAdmin: false
    chanOp: []

module.exports = UserDB
