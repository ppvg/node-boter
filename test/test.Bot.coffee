mockery = require 'mockery'
should = require 'should'
mocks = require './mocks'
sinon = require 'sinon'
path = require 'path'

boter = null
testManager =
  setup: ->
    mockery.enable()
    mockery.registerAllowables ['../', './lib/', './Bot', './Message', './regex', 'path', 'events', 'util', 'domain'], true
    mockery.registerMock 'irc', mocks.irc
    mockery.registerMock 'mkdirp',  mocks.mkdirp
    mockery.registerMock './UserDB',  mocks.UserDB
    boter = require '../'
  tearDown: ->
    mockery.deregisterAll()
    mockery.disable()
  resetMocks: ->
    mocks.irc.Client.reset()
    mocks.mkdirp.sync.reset()
    mocks.UserDB.reset()
    mocks.UserDB.prototype.setChanOp.reset()

describe 'Boter', ->
  bot = {}
  args = null # these are set in beforeEach, so they're reset before each test

  before     testManager.setup
  after      testManager.tearDown
  beforeEach ->
    testManager.resetMocks()
    args =
      server: 'irc.server.foo'
      name: 'BoterBot'
      opts:
        realName: 'Boter, the CoffeeScript bot'
        aliasses: ['Boter', 'MyBoter']
        channel: '#hack42'
    bot = new boter.Bot args.server, args.name, args.opts

  describe '#constructor', ->
    it 'should instantiate an irc.Client', ->
      mocks.irc.Client.calledWithNew().should.be.true


    describe 'when parsing the options', ->
      it 'include the nickname in the list of aliasses', ->
        bot.aliasses.should.eql ['boterbot', 'boter', 'myboter']

    describe 'when pluginPath and dataPath are not set', ->
      # Normally the base path is something like /home/users/project/mySuperBot
      # During testing it's something like /home/users/project/node-boter/test

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

    describe 'when loading the DB failed', ->
      it "should emit an 'error' event", (done) ->
        bot.on 'error', (err) -> done()
        bot.users.emit 'error'

  describe '#load', ->
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
          proxy.say.should.be.a 'function'
          proxy.action.should.be.a 'function'
          proxy.checkNickServ.should.be.a 'function'
          proxy.getUser.should.be.a 'function'
          called = true
          return plugin

        bot.load 'example', funcPlug
        called.should.be.true
        bot.plugins.example.should.equal plugin

  createTestOneOnOneBotToClient = (func) ->
    return ->
      bot.client[func] = sinon.spy()
      bot[func] 'context', 'message'
      bot.client[func].calledOnce.should.be.true
      bot.client[func].args[0][0].should.equal 'context'
      bot.client[func].args[0][1].should.equal 'message'

  describe '#say', ->
    it 'should call Client@say()', createTestOneOnOneBotToClient 'say'

  describe '#action', ->
    it 'should call Client@action()', createTestOneOnOneBotToClient 'action'

  describe '#checkNickServ', ->
    it 'should send a STATUS message to NickServ', ->
      bot.client.say = sinon.spy()
      bot.checkNickServ 'someUser', (isRegistered) -> # ignore
      bot.client.say.calledOnce.should.be.true
      bot.client.say.args[0][0].should.equal 'NickServ'
      bot.client.say.args[0][1].should.equal 'STATUS someUser'

  describe '#getUser', ->
    it 'callback should receive a user object', (done) ->
      bot.users.get = (nickname, callback) ->
        callback null, {nickname:nickname}
      bot.getUser 'someUser', (err, user) ->
        user.nickname.should.equal 'someUser'
        done()

    describe 'the user object', ->
      it 'should have additional methods #pm, #kick and #setIsAdmin', (done) ->
        bot.users.get = (nickname, callback) ->
          callback null, {nickname:nickname}
        bot.getUser 'someUser', (err, user) ->
          user.pm.should.be.a 'function'
          user.kick.should.be.a 'function'
          user.setIsAdmin.should.be.a 'function'
          done()

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

  describe 'when a NAMES list is received', ->
    it 'should call UserDB.setChanOp for every user', ->
      bot._onNames '#hack42',
        'op1': '@', 'op2': '@', 'regularuser': ''
      fn = bot.users.setChanOp
      fn.callCount.should.equal 3
      for i in [0..2]
        fn.args[i][0].should.equal '#hack42'
      fn.args[0][1].should.equal 'op1'
      fn.args[0][2].should.equal true
      fn.args[1][2].should.equal true
      fn.args[2][2].should.equal false

  describe 'when a MODE notice is received', ->
    describe 'when it sets +@ or -@ for a user', ->
      it 'should call UserDB.setChanOp', ->
        bot._onModeSet '#hack42', 'opuser', '@', 'targetuser', {}
        bot._onModeRemove '#hack42', 'opuser', '@', 'targetuser', {}
        fn = bot.users.setChanOp
        fn.callCount.should.equal 2
        for i in [0..1]
          fn.args[i][0].should.equal '#hack42'
          fn.args[i][1].should.equal 'targetuser'
        fn.args[0][2].should.equal true
        fn.args[1][2].should.equal false


