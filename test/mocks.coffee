sinon = require 'sinon'

IrcClient = sinon.spy()
IrcClient.prototype.say = sinon.spy()
IrcClient.prototype.on  = sinon.spy()

builtins = (bot) ->
  return plugin =
    example:
      help: "Example built-in command"
      run: (message) ->

module.exports =
  IrcClient: IrcClient
  builtins: builtins
