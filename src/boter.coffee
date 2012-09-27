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
    @handlers = []

exports.Boter = Boter
exports.User = User
exports.Message = Message
