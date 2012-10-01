mockery = require 'mockery'
EventEmitter = (require 'events').EventEmitter

ircConstructorSpy = new EventEmitter()
ircSaySpy = new EventEmitter()
class IrcClientMock extends EventEmitter
  constructor: (args...) ->
    ircConstructorSpy.emit 'construction', args...
  say: (args...) ->
    ircSaySpy.emit 'called', args...


describe 'Boter', ->
  Boter = {}
  args =
    server: 'irc.server.foo'
    name: 'MyBoter'
    opts:
      option: true
      aliasses: ['Boter', 'BoterBot']
  someUser = 'SomeUser'
  someMsg = 'The War of the Cookies is upon us!'

  before ->
    mockery.enable()
    mockery.registerAllowables ['../', './lib/boter', './lib-cov/boter', 'events']
    mockery.registerMock 'irc', {Client: IrcClientMock}
    {Boter} = (require '../')
  after ->
    mockery.deregisterMock 'irc'
    mockery.disable()

  describe 'constructor', ->
    it 'should pass on its arguments to the irc client', (done) ->
      called = false
      callback = (server, name, opts) ->
        called.should.be.false
        server.should.equal args.server
        name.should.equal args.name
        opts.should.eql args.opts
        called = true
        ircConstructorSpy.removeListener 'construction', callback
        done()
      ircConstructorSpy.on 'construction', callback
      bot = new Boter args.server, args.name, args.opts

    it 'should keep a list of aliasses', ->
      bot = new Boter args.server, args.name, args.opts
      bot.aliasses.should.eql ['myboter', 'boter', 'boterbot']

  describe 'when PM is received', ->
    bot = {}
    beforeEach ->
      bot = new Boter args.server, args.name, args.opts

    it 'should emit \'pm\' event with message object', (done) ->
      bot.on 'pm', (message) ->
        message.should.be.a 'object'
        message.from.should.equal someUser
        message.context.should.equal someUser # context matches the sender
        message.original.should.equal someMsg
        message.text.should.equal someMsg.toLowerCase()
        done()
      bot.client.emit 'pm', someUser, someMsg

    describe 'message#reply()', ->
      it 'should send a PM to the sender', (done) ->
        called = false
        callback = (context, message) ->
          context.should.equal someUser
          message.should.equal someMsg
          called = true
          ircSaySpy.removeListener 'called', callback
          done()
        ircSaySpy.on 'called', callback
        bot.on 'pm', (message) ->
          message.reply someMsg
        bot.client.emit 'pm', someUser, 'hi there!'

  describe 'when a public message is received', ->
    channel = '#cookies'
    bot = {}
    beforeEach ->
      bot = new Boter args.server, args.name, args.opts

    describe 'when the message starts with \'BotNick:\'', ->
      it 'should emit a \'highlight\' event', (done) ->
        bot.on 'highlight', -> done()
        msg = args.name+': '+someMsg
        bot.client.emit 'message#', someUser, channel, msg

      it 'should do the same if an alias is highlighted', (done) ->
        bot.on 'highlight', -> done()
        alias = args.opts.aliasses[1]
        msg = alias+': '+someMsg
        bot.client.emit 'message#', someUser, '#cookies', msg

      it 'should do this if someone else is highlighted', (done) ->
        highlighted = false
        bot.on 'highlight', -> highlighted = true
        msg = 'Stranger: '+someMsg
        callback = ->
          highlighted.should.be.false
          done()
        bot.client.emit 'message#', someUser, '#cookies', msg
        process.nextTick callback

      it 'should pass an instance of Message to the callback', (done) ->
        bot.on 'highlight', (message) ->
          message.should.be.a('object')
          message.constructor.name.should.equal 'Message'
          message.from.should.equal someUser
          message.context.should.equal channel
          done()
        msg = args.name+': '+someMsg
        bot.client.emit 'message#', someUser, channel, msg

      it 'should remove the \'BotNick: \' prefix from the message', (done) ->
        bot.on 'highlight', (message) ->
          message.should.be.a('object')
          message.from.should.equal someUser
          message.context.should.equal channel
          message.original.should.equal someMsg
          message.text.should.equal someMsg.toLowerCase()
          done()
        msg = args.name+': '+someMsg
        bot.client.emit 'message#', someUser, channel, msg

    describe 'when the message contains \'BotNick\'', ->
      it 'should emit a \'mention\' event', (done) ->
        bot.on 'mention', -> done()
        msg = someMsg+' might be something for '+args.name
        bot.client.emit 'message#', someUser, channel, msg

      it 'should do the same if an alias is mentioned', (done) ->
        bot.on 'mention', -> done()
        alias = args.opts.aliasses[1]
        msg = someMsg+' might be something for '+alias
        bot.client.emit 'message#', someUser, channel, msg

    describe 'message#reply()', ->
      it 'should send a message to the same channel', (done) ->
        called = false
        callback = (context, message) ->
          context.should.equal channel
          message.should.equal someMsg
          called = true
          ircSaySpy.removeListener 'called', callback
          done()
        ircSaySpy.on 'called', callback
        bot.on 'highlight', (message) ->
          message.reply someMsg
        msg = args.name+': hi there!'
        bot.client.emit 'message#', someUser, channel, msg

