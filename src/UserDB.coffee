dirty = require 'dirty'

class UserDB
  constructor: (filename) ->
    @db = dirty filename

  get: (nickname) ->
    console.log "Get user"
    (@db.get nickname) ? defaults()

  markRegistered: (nickname) ->
    user = @get nickname
    user.isRegistered = true
    @db.set nickname, user
    return user

  meet: (nickname) ->
    console.log 'meet'
    user = @get nickname
    if user?.isRegistered
      console.log 'isregistered'
      user.hasSudo = true
      @db.set nickname, user
      return true
    return false

  forget: (nickname) ->
    @db.rm nickname if (@db.get nickname)?

defaults = ->
  return userDefaults =
    isRegistered: false
    hasSudo: false

module.exports = UserDB
