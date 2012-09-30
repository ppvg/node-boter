#!/usr/bin/env coffee

irc = require 'irc'
show = console.log
error = console.error


class User
  constructor: (user, host) ->
    @user = user?.toLowerCase()
    @host = host?.toLowerCase()
  equals: (other) ->
    other.user.toLowerCase()==@user and other.host.toLowerCase()==@host


class Message
  constructor: (@from, @context, text) ->
    this.original = text
    this.text = text.toLowerCase()


class Boter
  constructor: (@server, @nickname, @config) ->
    @client = new irc.Client @server, @nickname, @config
    @handlers =
      'pm': [],
      'mention': [],
      'highlight': [],
      'other': []

  on: (args...) ->
    if args.length > 0
      if typeof args[0] is 'string'
        type = args[0]
        filter = () -> true
      else if typeof args[0] is 'function'
        type = 'other'
        filter = args[0]

    if args.length is 2
      if typeof args[0] isnt 'string'
        throw new Error "Invalid event type. First argument should be a string."
      if typeof args[1] isnt 'function'
        throw new Error "Invalid filter. Second argument should be a filter function."
      filter = args[1]

    if not eventTypes[type]?
      throw new Error "Not a valid event type: '#{ type }'"

    handlers = @handlers
    chainable =
      do: (callback) ->
        handlers[eventTypes[type]].push {
          'filter': filter,
          'handle': callback
        }

eventTypes =
  pm:        'pm',
  private:   'pm',
  query:     'pm',
  mention:   'mention',
  highlight: 'highlight',
  hilight:   'highlight',
  other:     'other',
  all:       'other',
  any:       'other',
  '*':       'other'


exports.Boter = Boter
exports.User = User
exports.Message = Message

