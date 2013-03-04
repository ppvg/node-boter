irc = require 'irc'
path = require 'path'
regex = require './regex'
Message = require './Message'


class Boter
  constructor: (@server, @nickname, @config) ->
    # Handle configuration and defaults:
    @aliasses = loadAliasses.call this
    @config[key] = val for key, val of configDefaults when not @config[key]?
    @plugins = []
    @commands = {}

    # Initialize the IRC client:
    @client = initializeIrcClient.call this
    @client.on 'pm', @_onPM
    @client.on 'message#', @_onOther

    # Load the built-in commands:
    

    ### Sensible DB path default: ###
    # require('path').dirname module.parent.parent.filename

  load: (plugin) ->
    if plugin in @plugins
      throw new Error "Plugin already loaded!"
    @plugins.push plugin
    if plugin.commands?
      loadCommands.call this, plugin.commands

  isCommand: (message) ->
    message.text.indexOf(@config.commandPrefix) is 0

  runCommand: (command, message) ->
    if @commands[command]?
      @commands[command].run message

  isHighlightedIn: (message) ->
    match = message.text.match regex.highlight
    match? and match[1] in @aliasses

  isMentionedIn: (message) ->
    containsAlias = (alias) -> message.text.indexOf(alias) > -1
    @aliasses.some containsAlias

  # Faux "private" methods:

  _onPM: (from, text) =>
    if from.toLowerCase() is 'nickserv'
      # Handle nickserv stuff
    else
      message = new Message from, from, text
      message.reply = (reply) =>
        @client.say from, reply
      if @isCommand message
        @_handleCommand message
      else
        @_handleEvent 'pm', message

  _onOther: (from, to, text) =>
    message = new Message from, to, text
    message.reply = (reply) =>
      @client.say to, reply

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

  _handleCommand: (message) ->
    command = message.trimCommand()
    @runCommand command, message

  _handleEvent: (eventType, message) ->
    for plugin in @plugins
      if plugin.events? and plugin.events.hasOwnProperty eventType
        plugin.events[eventType] message

# Real "private methods":

loadAliasses = ->
  aliasses = [@nickname.toLowerCase()]
  if @config?.aliasses?.length
    for alias in @config.aliasses
      aliasses.push alias.toLowerCase()
  aliasses

initializeIrcClient = ->
  new irc.Client @server, @nickname, @config

loadCommands = (commands) ->
  for name, command of commands
    if name of @commands
      console.error "Command '#{name}' already used by another plugin."
    else
      @commands[name] = command

# "Private properties":

eventTypes =
  pm: ['pm', 'private', 'query']
  highlight: ['highlight', 'hilight']
  mention: ['mention']
  other: ['other', 'public']
  all: ['all', 'any', '*']

basePath = path.dirname module.parent.parent.filename

configDefaults =
  commandPrefix: '!'
  pluginPath: path.resolve basePath, 'plugins'
  dataPath: path.resolve basePath, 'data'


module.exports = Boter
