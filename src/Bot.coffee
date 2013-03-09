irc = require 'irc'
path = require 'path'
mkdirp = require 'mkdirp'
events = require 'events'
domain = require 'domain'

regex = require './regex'
UserDB = require './UserDB'
Message = require './Message'

class Bot extends events.EventEmitter
  constructor: (@server, @nickname, config) ->
    # Handle configuration and defaults:
    @aliasses = aliasses @nickname, config.aliasses
    @config = {}
    for option in knownOpts
      @config[option] = config[option] ? (configDefaults[option] ? undefined)
    @plugins = {}
    @commands = {}
    @nickServQueue = []

    # Open user DB:
    @users = openUserDB.call this
    @users.once 'load', => @emit 'load'

    # Start IRC client:
    @client = initializeIrcClient @
    attachEventHandlers @client, @


  ### Plugin-accessable "public methods": ###

  say: (context, message) =>
    @client.say context, message

  action: (context, message) =>
    @client.action context, message

  checkNickServ: (nickname, callback) =>
    @_queueNickServCheck nickname, callback

  getUser: (nickname, callback) ->
    @users.get nickname, (err, user) =>
      if err?
        callback err
      else
        user.pm = (message) =>
          @client.say user.nickname, message
        user.kick = (channel, reason) =>
          @client.send 'KICK', channel, nickname, reason ? ''
        user.setIsAdmin = (isAdmin, callback) =>
          @db.setIsAdmin user.nickname, isAdmin, callback
        callback null, user

  ### Regular "public methods": ###

  createProxy: ->
    botProxy = {}
    for f in ['say', 'action', 'checkNickServ', 'getUser']
      botProxy[f] = @[f]
    botProxy.config = {}
    botProxy.config[key] = val for key, val of @config when typeof val is 'string'
    return botProxy

  load: (name, plugin) ->
    if typeof plugin is 'function'
      plugin = plugin @createProxy()

    if name of @plugins then throw new Error "Plugin '#{name}' already loaded!"

    @plugins[name] = plugin
    if plugin.commands?
      loadCommands.call this, plugin.commands
    return

  isCommand: (message) ->
    message.text.indexOf(@config.commandPrefix) is 0

  runCommand: (command, message) ->
    d = domain.create()
    d.on 'error', (err) =>
      @emit 'error', "[#{@config.commandPrefix}#{command}] " + err.toString()
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

  ### Faux "private" methods: ###

  _onPM: (from, text) =>
    @getUser from, (err, user) =>
      if err? then @emit 'error', new Error "Unhandled PM, can't get user #{from}."
      else
        message = new Message user, from, text
        message.reply = (reply) => @client.say from, reply

        if @isCommand message
          @_handleCommand message
        else
          @_handleEvent 'pm', message

  _onMessage: (from, to, text) =>
    @getUser from, (err, user) =>
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
      @users.setChanOp channel, nick, rank is '@'

  _onModeSet: (channel, setBy, mode, argument, message) =>
    if mode is 'o'
      @users.setChanOp channel, argument, true

  _onModeRemove: (channel, setBy, mode, argument, message) =>
    if mode is 'o'
      @users.setChanOp channel, argument, false

  _onJoin: (channel, nick, message) =>
    # TODO mark online?

  _handleCommand: (message) ->
    command = message.trimCommand()
    @runCommand command, message

  _handleEvent: (eventType, message) ->
    currentPlugin = null
    d = domain.create()
    d.on 'error', (err) =>
      @emit 'error', "[#{currentPlugin}:#{eventType}] " + err.toString()
    d.run =>
      for name, plugin of @plugins
        currentPlugin = name
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
        @users.setIsRegistered user.nick, true, (err, isRegistered) ->
          callback not err? and isRegistered
      else
        callback false
    if @nickServQueue.length > 0
      @client.say 'NickServ', "STATUS #{@nickServQueue[0].nick}"



### Real "private methods": ###

aliasses = (nickname, aliasses)->
  result = [nickname.toLowerCase()]
  if aliasses?.length
    for alias in aliasses
      result.push alias.toLowerCase()
  return result

initializeIrcClient = (bot) ->
  client = new irc.Client bot.server, bot.nickname, copyIrcOpts(bot.config)
  client.on 'error', (ircErr) =>
    err = new Error "[Client] " + ircErr.toString()
    bot.emit 'error', err
  return client

attachEventHandlers = (client, bot) ->
  client.on 'pm', bot._onPM
  client.on 'message#', bot._onMessage
  client.on 'notice', bot._onNotice
  client.on 'names', bot._onNames
  client.on '+mode', bot._onModeSet
  client.on '-mode', bot._onModeRemove
  client.on 'join', bot._onJoin
  # TODO
  # client.on 'part', bot._onPart # check NickServ status
  # client.on 'nick', bot._onNick # check NickServ status

copyIrcOpts = (config) ->
  return parsed =
    userName: config.userName, port: config.port,
    realName: config.realName, channels: config.channels

openUserDB = ->
  mkdirp.sync @config.dataPath
  filename = path.resolve @config.dataPath, 'users.tiny'
  db = new UserDB filename, @createProxy()
  db.once 'error', (err) =>
    @emit 'error', new Error "[UserDB] Failed to open database."
  db.on 'log', (message) =>
    @emit 'log', '[UserDB] ' + message
  return db

loadCommands = (commands) ->
  for name, command of commands
    if name of @commands
      @emit 'error', new Error "Command '#{name}' already used by another plugin."
    else
      @commands[name] = command

### "Private properties": ###

parent = module
insidePackage = ->
  if parent? then /(\/boter(\/(lib(-cov)?|test))?$)/i.test path.dirname parent.filename.toLowerCase() else false
while insidePackage() and parent.parent?.filename?
  parent = parent.parent
basePath = path.dirname parent.filename

configDefaults =
  commandPrefix: '!'
  pluginPath: path.resolve basePath, 'plugins'
  dataPath: path.resolve basePath, 'data'

knownOpts = [
  'userName', 'realName', 'port', 'channels' # IRC-related
  'commandPrefix', 'pluginPath', 'dataPath'  # Boter-related
]

eventTypes =
  pm: ['pm', 'private', 'query']
  highlight: ['highlight', 'hilight']
  mention: ['mention']
  other: ['other', 'public']
  all: ['all', 'any', '*']

module.exports = Bot
