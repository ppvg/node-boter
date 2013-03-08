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
          callback null, not err?
      else
        update = {}
        update[property] = value
        @db.update nickname, update, (err) ->
          callback null, not err?


class UserDB extends events.EventEmitter
  constructor: (filename, @bot) ->
    @db = null
    tiny filename, (err, db) =>
      if err?
        process.nextTick => @emit 'error', err
      else
        @db = db
        db.compact =>
          process.nextTick => @emit 'load'
          db.each ((doc) ->
              if doc.isRegistered or not doc.chanOp? or doc.chanOp.length > 0
                db.update doc.nickname, isRegistered:false, chanOp:[], (err) ->
            ), -> # done

  get: (nickname, callback) ->
    @emit 'debug', "Getting user '#{nickname}'"
    @_getOrDie nickname, (err, user) =>
      if err? then user = createDefaultUser()
      bot = @bot
      user.is = (role, arg) ->
        if role is 'op'
          if typeof arg isnt 'string' then throw new Error 'No channel specified.'
          else return @chanOp? and arg in @chanOp
        if role is 'registered'
          callback = if typeof arg is 'function' then arg else ->
          if user.isRegistered then callback true
          else bot.checkNickServ nickname, callback
        if role is 'admin'
          if typeof arg is 'function'
            user.is 'registered', (isRegistered) ->
              arg isRegistered and user.isAdmin
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

  _handleNickServ: (text) ->
    match = text.match regex.nickServStatus
    if match? and @nickServQueue.length > 0
      user = @nickServQueue.shift()
      callback = if typeof user.callback is 'function' then user.callback else ->
      if parseInt(match[1], 10) >= 2 
        @users.markRegistered user.nick, (err, marked) ->
          callback not err? and marked
      else
        callback false
    if @nickServQueue.length > 0
      @client.say 'NickServ', "STATUS #{@nickServQueue[0].nick}"

createDefaultUser = ->
  return userDefaults =
    isRegistered: false
    chanOp: []

module.exports = UserDB
