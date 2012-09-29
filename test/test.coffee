mockery = require 'mockery'
sinon = require 'sinon'

ircMock = { Client: sinon.spy() }
boter = {}

describe 'boter', ->
  before ->
    mockery.enable()
    mockery.registerMock 'irc', ircMock
    mockery.registerAllowable '../'
    mockery.registerAllowable './lib/boter'
    mockery.registerAllowable './lib-cov/boter'
    boter = require '../'

  after ->
    mockery.deregisterMock 'irc'
    mockery.disable()

  describe 'boter.User', ->
    describe '#equals()', ->
      it 'should return true if users have the same username and host', ->
        user1 = new boter.User 'user', 'some.host.foo'
        user2 = new boter.User 'user', 'some.host.foo'
        user1.equals(user2).should.be.true
      it 'should return false if usernames are different', ->
        user1 = new boter.User 'user', 'some.host.foo'
        user2 = new boter.User 'other', 'some.host.foo'
        user1.equals(user2).should.be.false
      it 'should return false if hostnames are different', ->
        user1 = new boter.User 'user', 'some.host.foo'
        user2 = new boter.User 'user', 'some.other.foo'
        user1.equals(user2).should.be.false

  describe 'boter.Message', ->
    describe 'Message()', ->
      text = "This is some Random Message with Important Capalization."
      message = {}
      beforeEach ->
        message = new boter.Message 'user', 'context', text
      it 'should save unmodified message in this.original', ->
        message.original.should.equal text
      it 'should make text lower case', ->
        message.text.should.equal text.toLowerCase()

  describe 'boter.Boter', ->
    args =
      server: 'irc.server.foo'
      name: 'MyBoter'
      opts: {'option': true}
    afterEach ->
      ircMock.Client.reset()
    describe 'Boter()', ->
      it 'should create irc client with same parameters', ->
        bot = new boter.Boter args.server, args.name, args.opts
        ircMock.Client.calledOnce.should.be.true
        ircMock.Client.calledWithNew().should.be.true
        ircMock.Client.calledWithExactly(args.server, args.name, args.opts).should.be.true

