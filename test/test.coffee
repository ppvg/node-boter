mockery = require 'mockery'
sinon = require 'sinon'


ircMock = { Client: sinon.spy() }
Boter = {}
Message = {}
User = {}


before ->
  mockery.enable()
  mockery.registerMock 'irc', ircMock
  mockery.registerAllowable '../'
  mockery.registerAllowable './lib/boter'
  mockery.registerAllowable './lib-cov/boter'
  {Boter, Message, User} = require '../'

after ->
  mockery.deregisterMock 'irc'
  mockery.disable()


describe 'User', ->
  describe '#equals()', ->
    it 'returns true if users have the same username and host', ->
      user1 = new User 'user', 'some.host.foo'
      user2 = new User 'user', 'some.host.foo'
      user1.equals(user2).should.be.true

    it 'returns false if usernames are different', ->
      user1 = new User 'user', 'some.host.foo'
      user2 = new User 'other', 'some.host.foo'
      user1.equals(user2).should.be.false

    it 'returns false if hostnames are different', ->
      user1 = new User 'user', 'some.host.foo'
      user2 = new User 'user', 'some.other.foo'
      user1.equals(user2).should.be.false


describe 'Message', ->
  text = "This is some Random Message with Important Capalization."
  message = {}
  beforeEach ->
    message = new Message 'user', 'context', text

  it 'keeps unmodified message in this.original', ->
    message.original.should.equal text

  it 'keeps decapitalized message in this.text', ->
    message.text.should.equal text.toLowerCase()


describe 'Boter', ->
  args =
    server: 'irc.server.foo'
    name: 'MyBoter'
    opts: {'option': true}
  afterEach ->
    ircMock.Client.reset()

  it 'creates irc client with same parameters', ->
    bot = new Boter args.server, args.name, args.opts
    ircMock.Client.calledOnce.should.be.true
    ircMock.Client.calledWithNew().should.be.true
    ircMock.Client.calledWithExactly(args.server, args.name, args.opts).should.be.true

  describe '#on()', ->
    bot = {}
    beforeEach ->
      bot = new Boter args.server, args.name, args.opts

    it 'returns object which has property #do()', ->
      do_obj = bot.on 'pm'
      do_obj.should.be.a('object').and.have.property('do')
      do_obj.do.should.be.a('function')

    it 'correctly categorizes handler types using the first parameter', ->
      testHandlerType ['pm', 'private', 'query'], 'pm'
      testHandlerType ['mention'], 'mention'
      testHandlerType ['highlight', 'highlight'], 'highlight'
      testHandlerType ['other', 'all', 'any', '*'], 'other'

    testHandlerType = (types, expected) ->
      dummy_handler = () -> 'test'
      bot.on(type).do(dummy_handler) for type in types
      bot.handlers.should.be.a('object').and.have.property(expected)
      bot.handlers[expected].should.have.lengthOf(types.length)
      for handler in bot.handlers[expected]
        handler.should.be.a('object')
        handler.filter.should.be.a('function')
        handler.handle.should.equal(dummy_handler)

    describe '#do()', ->


