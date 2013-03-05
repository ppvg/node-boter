sinon = require 'sinon'
events = require 'events'
util = require 'util'

IrcClient = sinon.spy()
IrcClient.prototype.say = sinon.spy()
IrcClient.prototype.on  = sinon.spy()

UserDB = sinon.spy()
util.inherits UserDB, events.EventEmitter
UserDB.prototype.get = (nickname, callback) ->
  callback null, {}

module.exports =
  irc: { Client: IrcClient }
  mkdirp: { sync: sinon.spy() }
  UserDB: UserDB
