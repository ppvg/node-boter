#!/usr/bin/env coffee

{EventEmitter} = require 'events'
irc = require 'irc'

show = console.log
error = console.error


class User
  constructor: (user, host) ->
    if not user or not host then throw new Error 'Invalid username or hostname.'
    @user = user.toLowerCase()
    @host = host.toLowerCase()
  equals: (other) ->
    other.user.toLowerCase()==@user and other.host.toLowerCase()==@host


class Message
  constructor: (@from, @context, text) ->
    @original = text
    @text = text.toLowerCase()
  trimHighlight: () ->
    @text = @text.replace highlightExpression, ''
    @original = @original.replace highlightExpression, ''


class Boter extends EventEmitter
  constructor: (@server, @nickname, @config) ->
    @aliasses = [@nickname.toLowerCase()]
    if @config?.aliasses?.length
      @aliasses.push alias.toLowerCase() for alias in @config.aliasses
    @client = new irc.Client @server, @nickname, @config

    @client.on 'pm', (from, text) =>
      message = new Message from, from, text
      message.reply = (reply) =>
        @client.say from, reply
      @emit 'pm', message

    @client.on 'message#', (from, to, text) =>
      message = new Message from, to, text
      message.reply = (reply) =>
        @client.say to, reply
      if @isHighlightedIn message
        message.trimHighlight()
        @emit 'highlight', message
      else if @isMentionedIn message
        @emit 'mention', message

  isHighlightedIn: (message) ->
    match = message.text.match highlightExpression
    match? and match[1] in @aliasses

  isMentionedIn: (message) ->
    containsAlias = (alias) -> message.text.indexOf(alias) > -1
    @aliasses.some containsAlias

# According to RCF 2812 (http://tools.ietf.org/html/rfc2812#section-2.3.1)
# nickname = ( letter / special ) *8( letter / digit / special / "-" )
# special  = "[", "]", "\", "`", "_", "^", "{", "|", "}"
highlightExpression = ///
  ^ # starts with
  (
    [a-zA-Z\[\]\\`_^\{|\}]     # letter / special
    [a-zA-Z0-9\[\]\\`_^\{|\}-] # letter / digit / special / '-'
      {1,15}                   # total length of 2 through 16
  )        # capture username
  [:;,]\s? # followed by ':', ';' or ',' (and optional whitespace)
///

eventTypes =
  pm: ['pm', 'private', 'query'],
  mention: ['mention'],
  highlight: ['highlight', 'hilight'],
  other: ['other', 'public'],
  all: ['all', 'any', '*']


exports.Boter = Boter
exports.User = User
exports.Message = Message
exports.highlightExpression = highlightExpression
