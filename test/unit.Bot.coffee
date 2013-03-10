# NB: Some modules are included via test/common.js
path = require 'path'

boter = Bot:
  sandbox.require libPath + 'Bot',
    requires:
      irc: mocks.irc
      mkdirp: mocks.mkdirp
      './UserDB': mocks.UserDB

resetMocks = ->
  mocks.irc.Client.reset()
  mocks.mkdirp.sync.reset()
  mocks.UserDB.reset()
  mocks.UserDB.prototype.setChanOp.reset()


describe 'Bot', ->
  bot = {}
  args = null # these are set in beforeEach, so they're reset before each test

  beforeEach ->
    resetMocks()
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
      expect(mocks.irc.Client).to.have.been.calledWithNew

    describe 'when parsing the options', ->
      it 'include the nickname in the list of aliasses', ->
        expect(bot.aliasses).to.eql ['boterbot', 'boter', 'myboter']

    describe 'when pluginPath and dataPath are not set', ->
      ###
      Normally the base path is something like /home/users/project/mySuperBot
      During testing it's something like /home/users/project/node-boter/test

      CORRECTION: skipping these tests for now, because loading with
      `sandboxed-module` means that `module.parent` is always `undefined`.
      ###
      basePath = path.dirname module.filename
      it.skip 'should set a default plugin path relative to the parent module', ->
        expect(bot.config.pluginPath).to.equal path.resolve(basePath, 'plugins')
      it.skip 'should set a default data path relative to the parent module', ->
        expect(bot.config.dataPath).to.equal path.resolve(basePath, 'data')

    it 'should create the user DB', ->
      expect(mocks.mkdirp.sync).to.have.been.calledOnce
      expect(mocks.UserDB).to.have.been.calledWithNew

    describe 'when the DB is successfully loaded', ->
      it "should emit a 'load' event", (done) ->
        bot.on 'load', ->
          done()
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
      expect(bot.plugins.example).to.equal plugin
      expect(n for n,p of bot.plugins).to.have.length 1

    it "should add the plugin's commands to bot.commands", ->
      bot.load 'example', plugin
      expect(bot.commands.barrelroll).to.equal plugin.commands.barrelroll
      expect(bot.commands.boter).to.equal plugin.commands.boter

    describe 'when the same plugin is added twice', ->
      it 'should throw an error', ->
        bot.load 'example', plugin
        (-> bot.load 'example', plugin).should.throw()

    describe 'when the plugin is a function', ->
      it 'should be called with a botProxy as argument', ->
        called = false
        funcPlug = (proxy) ->
          expect(proxy.say).to.be.a 'function'
          expect(proxy.action).to.be.a 'function'
          expect(proxy.checkNickServ).to.be.a 'function'
          expect(proxy.getUser).to.be.a 'function'
          called = true
          return plugin

        bot.load 'example', funcPlug
        expect(called).to.be.true
        expect(bot.plugins.example).to.equal plugin

  createTest_oneOnOneBotToClient = (func) ->
    return ->
      bot.client[func] = sinon.spy()
      bot[func] 'context', 'message'
      expect(bot.client[func]).to.be.calledOnce
      expect(bot.client[func]).to.be.calledWith 'context', 'message'

  describe '#say', ->
    it 'should call Client@say()', createTest_oneOnOneBotToClient 'say'

  describe '#action', ->
    it 'should call Client@action()', createTest_oneOnOneBotToClient 'action'

  describe '#checkNickServ', ->
    it 'should send a STATUS message to NickServ', ->
      bot.client.say = sinon.spy()
      bot.checkNickServ 'someUser', (isRegistered) -> # ignore
      expect(bot.client.say).to.have.been.calledOnce
      expect(bot.client.say).to.have.been.calledWith 'NickServ', 'STATUS someUser'

  describe '#getUser', ->
    it 'callback should receive a user object', (done) ->
      bot.users.get = (nickname, callback) ->
        callback null, {nickname:nickname}
      bot.getUser 'someUser', (err, user) ->
        expect(user.nickname).to.equal 'someUser'
        done()

    describe 'the user object', ->
      it 'should have additional methods #pm, #kick and #setIsAdmin', (done) ->
        bot.users.get = (nickname, callback) ->
          callback null, {nickname:nickname}
        bot.getUser 'someUser', (err, user) ->
          expect(user.pm).to.be.a 'function'
          expect(user.kick).to.be.a 'function'
          expect(user.setIsAdmin).to.be.a 'function'
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
        expect(message.text).to.eql 'something'
        expect(message.original).to.eql 'SOMEthing'
        done() if (callbacks += 1) >= 2

      bot.load 'example', plugin
      bot._onPM 'userx', '!test SOMEthing'
      bot._onMessage 'userx', '#hack42', '!test SOMEthing'

    describe 'when config.commandPrefix is set', ->
      it 'should still correctly identify commands', (done) ->
        bot.config.commandPrefix = '@'
        callbacks = 0
        plugin.commands.test = (message) ->
          expect(message.text).to.eql 'something'
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
        'op1': '@', 'user': ''
      fn = bot.users.setChanOp
      expect(fn).to.have.been.calledTwice
      expect(fn.getCall 0).to.have.been.calledWith '#hack42', 'op1', true
      expect(fn.getCall 1).to.have.been.calledWith '#hack42', 'user', false

  describe 'when a MODE notice is received', ->
    describe 'when it sets +o or -o for a user', ->
      it 'should call UserDB.setChanOp', ->
        bot._onModeSet '#hack42', 'opuser', 'o', 'user', {}
        bot._onModeRemove '#hack42', 'opuser', 'o', 'user', {}
        fn = bot.users.setChanOp
        expect(fn).to.have.been.calledTwice
        expect(fn.getCall 0).to.have.been.calledWith '#hack42', 'user', true
        expect(fn.getCall 1).to.have.been.calledWith '#hack42', 'user', false


