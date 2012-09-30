#!/usr/bin/env coffee

{EventEmitter} = require 'events'
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
    @original = text
    @text = text.toLowerCase()
  trimMentionPrefix: () ->
    @text = @text.replace mentionExpression, ''
    @original = @original.replace mentionExpression, ''


class Boter extends EventEmitter
  constructor: (@server, @nickname, @config) ->
    @aliasses = [@nickname.toLowerCase()]
    if @config?.aliasses?.length
      @aliasses.push alias.toLowerCase() for alias in @config.aliasses
    @client = new irc.Client @server, @nickname, @config

    @client.on 'pm', (from, text) =>
      message = new Message from, from, text
      @emit 'pm', message

    @client.on 'message#', (from, to, text) =>
      message = new Message from, to, text
      if @isMentionedIn message
        message.trimMentionPrefix()
        @emit 'mention', message
    #   else if indexOfNick isnt -1
    #     highlight = true

  isMentionedIn: (message) ->
    mentioned = false
    match = message.text.match mentionExpression
    if match? and match[1] in @aliasses
      mentioned = true
    mentioned

  isHighlightedIn: (message) ->


# According to RCF 2812 (http://tools.ietf.org/html/rfc2812#section-2.3.1)
# nickname = ( letter / special ) *8( letter / digit / special / "-" )
# special  = "[", "]", "\", "`", "_", "^", "{", "|", "}"
mentionExpression = ///
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
exports.mentionExpression = mentionExpression
