regex = require './regex'

class Message
  constructor: (@from, @context, text) ->
    @original = text
    @text = text.toLowerCase()
  trimHighlight: () ->
    @text = @text.replace regex.highlight, ''
    @original = @original.replace regex.highlight, ''
  trimCommand: () ->
    command = @text.match(regex.command)?.slice(1)
    @text = @text.replace regex.command, ''
    @original = @original.replace regex.command, ''
    return command
  trim: () -> # whitespace from beginning and end
    @text = @text.replace(/^\s*/, '').replace(/\s*$/, '')
    @original = @original.replace(/^\s*/, '').replace(/\s*$/, '')

module.exports = Message
