mockery = require 'mockery'
should = require 'should'
mocks = require './mocks'
path = require 'path'

boter = null
testManager =
  setup: ->
    mockery.enable()
    mockery.registerAllowables ['../', './lib/', './Bot', './Message', './regex', 'path', 'events', 'util', 'domain']
    mockery.registerMock 'irc', mocks.irc
    mockery.registerMock 'mkdirp',  mocks.mkdirp
    mockery.registerMock './UserDB',  mocks.UserDB
    boter = require '../'
  tearDown: ->
    mockery.deregisterMock 'irc'
    mockery.deregisterMock 'mkdirp'
    mockery.deregisterMock './UserDB'
    mockery.disable()
    boter = null
  resetMocks: ->
    mocks.irc.Client.reset()
    mocks.mkdirp.sync.reset()
    mocks.UserDB.reset()

describe 'Boter', ->
  bot = {}
  args =
    server: 'irc.server.foo'
    name: 'BoterBot'
    opts:
      realName: 'Boter, the CoffeeScript bot'
      aliasses: ['Boter', 'MyBoter']

  before     testManager.setup
  after      testManager.tearDown
  beforeEach ->
    testManager.resetMocks()
    bot = new boter.Bot args.server, args.name, args.opts

  describe 'constructor', ->
    it 'should instantiate an irc.Client', ->
      mocks.irc.Client.calledWithNew().should.be.true

    it 'should keep a list of aliasses', ->
      bot.aliasses.should.eql ['boterbot', 'boter', 'myboter']

    # normally something like /home/users/project/mySuperBot
    # while testing something like /home/users/project/node-boter/test
    basePath = path.dirname module.filename

    it 'should set a default plugin path relative to the parent module', ->
      bot.config.pluginPath.should.equal path.resolve(basePath, 'plugins')

    it 'should set a default data path relative to the parent module', ->
      bot.config.dataPath.should.equal path.resolve(basePath, 'data')

    it 'should create the user DB', ->
      mocks.mkdirp.sync.calledOnce.should.be.true
      mocks.UserDB.calledWithNew().should.be.true

    describe 'when the DB is successfully loaded', ->
      it "should emit a 'load' event", (done) ->
        bot.on 'load', done
        bot.users.emit 'load'

    describe 'when loading the DB fails', ->
      it "should emit an 'error' event", (done) ->
        bot.on 'error', (err) -> done()
        bot.users.emit 'error'

  describe 'load plugin', ->
    plugin =
      events:
        highlight: (message) ->
      commands:
        barrelroll: (message) ->
        boter: (message) ->

    it 'should add the plugin to bot.plugins', ->
      bot.load 'example', plugin
      bot.plugins.example.should.equal plugin
      (n for n,p of bot.plugins).length.should.equal 1

    it "should add the plugin's commands to bot.commands", ->
      bot.load 'example', plugin
      bot.commands.barrelroll.should.equal plugin.commands.barrelroll
      bot.commands.boter.should.equal plugin.commands.boter

    describe 'when the same plugin is added twice', ->
      it 'should throw an error', ->
        bot.load 'example', plugin
        (-> bot.load 'example', plugin).should.throw()

    describe 'when the plugin is a function', ->
      it 'should be called with a botProxy as argument', ->
        called = false
        funcPlug = (proxy) ->
          proxy.meet.should.be.a 'function'
          proxy.forget.should.be.a 'function'
          proxy.say.should.be.a 'function'
          called = true
          return plugin

        bot.load 'example', funcPlug
        called.should.be.true
        bot.plugins.example.should.equal plugin

  describe 'when a command is received', ->
    plugin =
      commands:
        test: (message) ->

    it "should call the correct plugin", (done) ->
      callbacks = 0
      plugin.commands.test = (message) ->
        done() if (callbacks += 1) >= 2

      bot.load 'example', plugin
      bot._onPM 'userx', '!test something'
      bot._onMessage 'userx', '#hack42', '!test something'

    it 'should trim the command from the text', (done) ->
      callbacks = 0
      plugin.commands.test = (message) ->
        message.text.should.eql 'something'
        message.original.should.eql 'SOMEthing'
        done() if (callbacks += 1) >= 2

      bot.load 'example', plugin
      bot._onPM 'userx', '!test SOMEthing'
      bot._onMessage 'userx', '#hack42', '!test SOMEthing'

    describe 'when config.commandPrefix is set', ->
      it 'should still correctly identify commands', (done) ->
        bot.config.commandPrefix = '@'
        callbacks = 0
        plugin.commands.test = (message) ->
          message.text.should.eql 'something'
          done() if (callbacks += 1) >= 2

        bot.load 'example', plugin
        bot._onPM 'userx', '@test something'
        bot._onMessage 'userx', '#hack42', '@test something'

  describe 'when a normal PM is received', ->
    it "should call the plugin's 'pm' event handler", (done) ->
      plugin =
        events:
          pm: (message) -> done()
      bot.load 'example', plugin
      bot._onPM 'userx', 'something'

  describe 'when a public message is received', ->
    describe 'when it highlights the bot', ->
      it "should call the plugin's 'highlight' event handler", (done) ->
        plugin =
          events:
            highlight: (message) -> done()
        bot.load 'example', plugin
        bot._onMessage 'userx', '#hack42', 'BoterBot: something'

    describe 'when it mentions the bot', ->
      it "should call the plugin's 'mention' event handler", (done) ->
        plugin =
          events:
            mention: (message) -> done()
        bot.load 'example', plugin
        bot._onMessage 'userx', '#hack42', 'Something about Boterbot'

    describe "when it's an ordinary message", ->
      it "should call the plugin's 'other' event handler", (done) ->
        plugin =
          events:
            other: (message) -> done()
        bot.load 'example', plugin
        bot._onMessage 'userx', '#hack42', 'Something about ponies'
