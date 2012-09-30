describe 'mentionExpression', ->
  mentionExpression = {}
  validNicks = [
    'nick',
    '^nick',
    '\\awesome\\nick',
    '{i`m_nick}',
    '[hi-there]',
    '|nick^master|',
    'just_long_enough'
  ]
  invalidNicks = [
    'tiny_bit_too_long'
    'very_long_nick_is_very_long_indeed',
    'a',
    '0|nick',
    '-not_me',
    'hey_there!',
    'art~ful',
    '"someone"'
  ]
  test = (nick, expected) ->
    (mentionExpression.test nick).should.equal expected

  before ->
    {mentionExpression} = require '../'

  describe 'when the nickname is invalid', ->
    it 'should never match', ->
      for nick in invalidNicks
        test nick, false
        test nick+' ', false
        test nick+': ', false
        test nick+'; ', false
        test nick+', ', false

  describe 'when the nickname if valid', ->
    it 'should not match \'nickname\' or \'nickname \'', ->
      for nick in validNicks
        test nick, false
        test nick+' ', false
    it 'should match \'nickname: \', \'nickname; \' and \'nickname, \'', ->
      for nick in validNicks
        test nick+': ', true
        test nick+'; ', true
        test nick+', ', true
