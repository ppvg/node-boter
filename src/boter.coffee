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

  on: (type, filter) ->
    handlers = @handlers
    chainable =
      do: (callback) ->
        isString = typeof type is 'string'
        isEvent = eventTypes[type]?
        if isString and isEvent
          if typeof filter isnt 'function'
            filter = () -> true
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

