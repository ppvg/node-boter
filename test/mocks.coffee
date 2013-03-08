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
UserDB.prototype.setChanOp = sinon.spy()

tinyspy = sinon.spy()
tinyGood = (filename, callback) ->
  callback null, tinyspy
tinyBad = (filename, callback) ->
  callback new Error "Trololo"

module.exports =
  irc: { Client: IrcClient }
  mkdirp: { sync: sinon.spy() }
  UserDB: UserDB
  tinyGood: tinyGood
  tinyBad: tinyBad
  tinyspy: tinyspy
