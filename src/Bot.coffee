irc = require 'irc'
path = require 'path'
mkdirp = require 'mkdirp'
events = require 'events'
domain = require 'domain'

regex = require './regex'
UserDB = require './UserDB'
Message = require './Message'

class Bot extends events.EventEmitter
  constructor: (@server, @nickname, @config) ->
    # Handle configuration and defaults:
    @aliasses = loadAliasses.call this
    @config[key] = val for key, val of configDefaults when not @config[key]?
    @plugins = {}
    @commands = {}
    @nickServQueue = []

    # Open user DB:
    @users = openUserDB.call this
    @users.once 'load', =>
      @emit 'load'

    # Start IRC client:
    @client = initializeIrcClient.call this
    @client.on 'pm', @_onPM
    @client.on 'message#', @_onMessage
    @client.on 'notice', @_onNotice
    @client.on 'names', @_onNames
    @client.on 'join', @_onJoin

    # Request /names every 2 minutes (to update NickServ status)
    requestNames = =>
      @client.send 'NAMES', channel for channel in @config?.channels
    setInterval requestNames, 1000*60*2

  # Plugin-accessable "public methods":

  meet: (user, callback) =>
    callback = callback ? ( (err, met) -> )

    if typeof user isnt 'string' and user.isRegistered
      @users.meet user.nickname, callback
    else
      @_queueNickServCheck user, (isRegistered) =>
        if isRegistered
          @users.meet user, callback
        else
          callback null, false

  forget: (user, callback) =>
    if not typeof user is 'string'
      user = user?.nickname
    callback = callback ? ( (err) -> )
    @users.forget user, callback

  say: (context, message) =>
    @client.say context, message

  # Regular "public methods":

  load: (name, plugin) ->
    if typeof plugin is 'function'
      botProxy = {}
      botProxy[f] = @[f] for f in ['meet', 'forget', 'say']
      botProxy.config = {}
      botProxy.config[key] = val for key, val of @config when typeof val is 'string'
      plugin = plugin botProxy

    if name of @plugins then throw new Error "Plugin already loaded!"

    @plugins[name] = plugin
    if plugin.commands?
      loadCommands.call this, plugin.commands

  isCommand: (message) ->
    message.text.indexOf(@config.commandPrefix) is 0

  runCommand: (command, message) ->
    d = domain.create()
    d.on 'error', (err) =>
      @emit 'error', "[runCommand] " + err.toString()
    d.run =>
      cmd = @commands[command]
      if typeof cmd is 'function' then cmd message
      else if cmd?.run? then cmd.run message

  isHighlightedIn: (message) ->
    match = message.text.match regex.highlight
    match? and match[1] in @aliasses

  isMentionedIn: (message) ->
    containsAlias = (alias) -> message.text.indexOf(alias) > -1
    @aliasses.some containsAlias

  # Faux "private" methods:

  _onPM: (from, text) =>
    @_getUser from, (err, user) =>
      if err? then @emit 'error', new Error "Unhandled PM, can't get user #{from}."
      else
        message = new Message user, from, text
        message.reply = (reply) => @client.say from, reply

        if @isCommand message
          @_handleCommand message
        else
          @_handleEvent 'pm', message

  _onMessage: (from, to, text) =>
    @_getUser from, (err, user) =>
      if err? then @emit 'error', new Error "Unhandled message, can't get user #{from}."
      else
        message = new Message user, to, text
        message.reply = (reply) => @client.say to, reply

        if @isCommand message
          @_handleCommand message
        else if @isHighlightedIn message
          message.trimHighlight()
          @_handleEvent 'highlight', message
        else if @isMentionedIn message
          @_handleEvent 'mention', message
        else
          @_handleEvent 'other', message

        @_handleEvent 'all', message

  _onNotice: (nick, to, text, message) =>
    if nick?.toLowerCase() is 'nickserv'
      @_handleNickServ text

  _onNames: (channel, nicks) =>
    for nick, rank of nicks
      @_queueNickServCheck nick

  _onJoin: (channel, nick, message) =>
    @_queueNickServCheck nick

  _handleCommand: (message) ->
    command = message.trimCommand()
    @runCommand command, message

  _handleEvent: (eventType, message) ->
    d = domain.create()
    d.on 'error', (err) =>
      @emit 'error', "[_handleEvent] " + err.toString()
    d.run =>
      for name, plugin of @plugins
        if plugin.events? and plugin.events.hasOwnProperty eventType
          plugin.events[eventType] message

  _queueNickServCheck: (nick, callback) =>
    @nickServQueue.push {nick, callback} unless nick is @nickname
    if @nickServQueue.length == 1
      @client.say 'NickServ', "STATUS #{@nickServQueue[0].nick}"

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

  _getUser: (nickname, callback) ->
    @users.get nickname, (err, user) =>
      # if err? then callback err
      if err?
        callback err
      else
        user.nickname = nickname
        user.pm = (message) =>
          @client.say user.nickname, message
        user.kick = (channel, reason) =>
          @client.send 'KICK', channel, nickname, reason ? ''
        user.is = (role) =>
          if role is 'super' or role is 'privileged'
            user.isRegistered and user.hasSudo
          else if role is 'admin'
            user.isRegistered and user.isAdmin
        callback null, user


# Real "private methods":

loadAliasses = ->
  aliasses = [@nickname.toLowerCase()]
  if @config?.aliasses?.length
    for alias in @config.aliasses
      aliasses.push alias.toLowerCase()
  aliasses

initializeIrcClient = ->
  client = new irc.Client @server, @nickname, @config
  client.on 'error', (ircErr) =>
    err = new Error "IRC client error:" + ircErr.toString()
    @emit 'error', err
  return client

openUserDB = ->
  mkdirp.sync @config.dataPath
  db = new UserDB path.resolve @config.dataPath, 'users.tiny'
  db.once 'error', (err) =>
    @emit 'error', new Error "Failed to open user database."
  db.on 'log', (message) =>
    @emit 'log', '[UserDB] ' + message
  return db

loadCommands = (commands) ->
  for name, command of commands
    if name of @commands
      @emit 'error', new Error "Command '#{name}' already used by another plugin."
    else
      @commands[name] = command

# "Private properties":

eventTypes =
  pm: ['pm', 'private', 'query']
  highlight: ['highlight', 'hilight']
  mention: ['mention']
  other: ['other', 'public']
  all: ['all', 'any', '*']

parent = module.parent
insidePackage = -> 
  /(\/boter\/lib$)|(\/boter$)/.test path.dirname parent.filename.toLowerCase()
while insidePackage()
  parent = parent.parent
basePath = path.dirname parent.filename

configDefaults =
  commandPrefix: '!'
  pluginPath: path.resolve basePath, 'plugins'
  dataPath: path.resolve basePath, 'data'
  channels: []


module.exports = Bot
