mockery = require 'mockery'
EventEmitter = (require 'events').EventEmitter

ircSpy = new EventEmitter()
class IrcClientMock extends EventEmitter
  constructor: (args...) ->
    ircSpy.emit 'construction', args...


describe 'Boter', ->
  Boter = {}
  args =
    server: 'irc.server.foo'
    name: 'MyBoter'
    opts: {'option': true}

  before ->
    mockery.enable()
    mockery.registerAllowable '../'
    mockery.registerAllowable './lib/boter'
    mockery.registerAllowable './lib-cov/boter'
    mockery.registerMock 'irc', {Client: IrcClientMock}
    {Boter} = (require '../')
  after ->
    mockery.deregisterMock 'irc'

  describe 'constructor', ->
    it 'should pass on its argument to the irc client', (done) ->
      called = false
      callback = (server, name, opts) ->
        called.should.be.false
        server.should.equal args.server
        name.should.equal args.name
        opts.should.equal args.opts
        called = true
        ircSpy.removeListener 'construction', callback
        done()
      ircSpy.on 'construction', callback
      bot = new Boter args.server, args.name, args.opts

  describe '#on()', ->
    dummy_handler = (message, bot) -> bot.say message.context, 'test'
    dummy_filter = (message) -> message.text == '42'
    bot = {}

    beforeEach ->
      bot = new Boter args.server, args.name, args.opts

    it 'should return an object with a property #do()', ->
      do_obj = bot.on 'pm'
      do_obj.should.be.a('object').and.have.property 'do'
      do_obj.do.should.be.a 'function'

    describe 'when given a string as the first argument', ->
      it 'should use it as the event type', ->
        testHandlerType ['pm', 'private', 'query'], 'pm'
        testHandlerType ['mention'], 'mention'
        testHandlerType ['highlight', 'highlight'], 'highlight'
        testHandlerType ['other', 'all', 'any', '*'], 'other'

      testHandlerType = (types, expected) ->
        # Note: this depends on #do() to work correctly.
        bot.on(type).do(dummy_handler) for type in types
        bot.handlers.should.be.a('object').and.have.property expected
        bot.handlers[expected].should.have.length types.length

      it 'should throw an Error if it is invalid or unknown', ->
        ( -> bot.on('invalid').do(dummy_handler))
          .should.throw()
        handlers.should.be.empty for handlers in bot.handlers

    describe 'when given only a string', ->
      it 'should offer default filter() which always returns true', ->
        bot.on('pm').do(dummy_handler)
        handler = bot.handlers['pm'][0]
        handler.filter().should.be.true
        handler.handle.should.equal dummy_handler

    describe 'when given only a filter() function', ->
      it 'should categorize the event as \'other\'', ->
        bot.on(dummy_filter).do(dummy_handler)
        other = bot.handlers['other']
        other.should.have.length 1
        other[0].filter.should.equal dummy_filter

    describe 'when given a string and a function', ->
      it 'should use string as event type and function as filter', ->
        bot.on('pm', dummy_filter).do(dummy_handler)
        pm = bot.handlers['pm']
        pm.should.have.length 1
        pm[0].filter.should.equal dummy_filter

    describe '#do()', ->
      describe 'when given only a function', ->
        it 'should store the event with the function as its handler', ->
          types = ['pm', 'mention', 'highlight', 'other']
          bot.on(type, dummy_filter).do(dummy_handler) for type in types
          for type in types
            bot.handlers.should.have.property(type)
            for handler in bot.handlers
              handler.should.be.a 'object'
              handler.filter.should.equal dummy_filter
              handler.handle.should.equal dummy_handler

      describe 'when given something other than a function', ->
        it 'should throw an Error', ->
          ( -> bot.on(dummy_filter).do('a little dance'))
            .should.throw()
          bot.handlers['other'].should.have.length 0

  describe 'when an event is received from the IRC Client', ->
    bot = {}

    beforeEach ->
      bot = new Boter args.server, args.name, args.opts

    describe.skip 'when it is a PM', ->
      describe 'when a PM handler is registered', ->
        it 'should be passed to a PM handler if one is registered', (done) ->
          called = false
          bot.on('pm').do((message) ->
            console.log "MESSAGE!!!!\n\n\n\n"
            called.should.be.false
            message.text.should.equal 'Message!'
            called = true
            done()
          )
          bot.client.emit 'pm', 'someone', 'Message!'
