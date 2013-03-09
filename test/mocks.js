var events = require('events');
var sinon = require('sinon');
var util = require('util');

var IrcClient = sinon.spy();
IrcClient.prototype.say = sinon.spy();
IrcClient.prototype.on = sinon.spy();

var UserDB = sinon.spy();
util.inherits(UserDB, events.EventEmitter);
UserDB.prototype.get = function(nickname, callback) {
  return callback(null, {});
};
UserDB.prototype.setChanOp = sinon.spy();

var tinySpy = sinon.spy();
var tinyGood = function(filename, callback) {
  return callback(null, tinySpy);
};
var tinyBad = function(filename, callback) {
  return callback(new Error("Trololo"));
};

module.exports = {
  irc: {
    Client: IrcClient
  },
  mkdirp: {
    sync: sinon.spy()
  },
  UserDB: UserDB,
  tinySpy: tinySpy,
  tinyGood: tinyGood,
  tinyBad: tinyBad
};
