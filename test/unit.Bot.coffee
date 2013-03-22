# NB: Some modules are included via test/common.js
path = require 'path'

boter = null
loadBoter = ->
  boter =
    Bot: (sandbox.require libPath + 'Bot', requires:
      irc: mocks.irc
      mkdirp: mocks.mkdirp
      './UserDB': mocks.UserDB
    )

resetMocks = ->
  mocks.irc.Client.reset()
  mocks.mkdirp.sync.reset()
  mocks.UserDB.reset()
  mocks.UserDB.prototype.setChanOp.reset()


describe 'Bot', ->

  before -> loadBoter()

  beforeEach ->
    resetMocks()
    this.args =
      server: 'irc.server.foo'
      name: 'BoterBot'
      opts:
        realName: 'Boter, the CoffeeScript bot'
        aliasses: ['Boter', 'MyBoter']
        channel: '#hack42'
    this.bot = new boter.Bot this.args.server, this.args.name, this.args.opts

  describe '#constructor', ->
    it 'should instantiate an irc.Client', ->
      expect(mocks.irc.Client).to.have.been.calledWithNew

    describe 'when parsing the options', ->
      it 'include the nickname in the list of aliasses', ->
        expect(this.bot.aliasses).to.eql ['boterbot', 'boter', 'myboter']

    describe 'when pluginPath and dataPath are not set', ->
      ###
      Normally the base path is something like /home/users/project/mySuperBot
      During testing it's something like /home/users/project/node-boter/test

      CORRECTION: skipping these tests for now, because loading with
      `sandboxed-module` means that `module.parent` is always `undefined`.
      ###
      basePath = path.dirname module.filename
      it.skip 'should set a default plugin path relative to the parent module', ->
        expect(this.bot.config.pluginPath).to.equal path.resolve(basePath, 'plugins')
      it.skip 'should set a default data path relative to the parent module', ->
        expect(this.bot.config.dataPath).to.equal path.resolve(basePath, 'data')

    it 'should create the user DB', ->
      expect(mocks.mkdirp.sync).to.have.been.calledOnce
      expect(mocks.UserDB).to.have.been.calledWithNew

    describe 'when the DB is successfully loaded', ->
      it "should emit a 'load' event", (done) ->
        this.bot.on 'load', ->
          done()
        this.bot.users.emit 'load'

    describe 'when loading the DB failed', ->
      it "should emit an 'error' event", (done) ->
        this.bot.on 'error', (err) -> done()
        this.bot.users.emit 'error'

  describe '#load', ->
    plugin =
      events:
        highlight: (message) ->
      commands:
        barrelroll: (message) ->
        boter: (message) ->

    it 'should add the plugin to bot.plugins', ->
      this.bot.load 'example', plugin
      expect(this.bot.plugins.example).to.equal plugin
      expect(n for n,p of this.bot.plugins).to.have.length 1

    it "should add the plugin's commands to bot.commands", ->
      this.bot.load 'example', plugin
      expect(this.bot.commands.barrelroll).to.equal plugin.commands.barrelroll
      expect(this.bot.commands.boter).to.equal plugin.commands.boter

    describe 'when the same plugin is added twice', ->
      it 'should throw an error', ->
        this.bot.load 'example', plugin
        (-> this.bot.load 'example', plugin).should.throw()

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

        this.bot.load 'example', funcPlug
        expect(called).to.be.true
        expect(this.bot.plugins.example).to.equal plugin

  createTest_oneOnOneBotToClient = (func) ->
    return ->
      this.bot.client[func] = sinon.spy()
      this.bot[func] 'context', 'message'
      expect(this.bot.client[func]).to.be.calledOnce
      expect(this.bot.client[func]).to.be.calledWith 'context', 'message'

  describe '#say', ->
    it 'should call Client#say()', createTest_oneOnOneBotToClient 'say'

  describe '#action', ->
    it 'should call Client#action()', createTest_oneOnOneBotToClient 'action'

  describe '#checkNickServ', ->
    it 'should send a STATUS message to NickServ', ->
      this.bot.client.say = sinon.spy()
      this.bot.checkNickServ 'someUser', (isRegistered) -> # ignore
      expect(this.bot.client.say).to.have.been.calledOnce
      expect(this.bot.client.say).to.have.been.calledWith 'NickServ', 'STATUS someUser'

  describe '#getUser', ->
    describe 'when the UserDB returns an error', ->
      it "should pass the error to the callback", (done) ->
        userDBError = new Error 'User database not available'
        this.bot.users.get = (nickname, callback) ->
          callback userDBError
        this.bot.getUser 'someUser', (err, user) ->
          expect(user).to.not.exist
          expect(err).to.equal userDBError
          done()

    it 'callback should receive a user object', (done) ->
      this.bot.users.get = (nickname, callback) ->
        callback null, {nickname:nickname}
      this.bot.getUser 'someUser', (err, user) ->
        expect(user.nickname).to.equal 'someUser'
        done()

    describe 'user#pm(message)', ->
      it 'should send a PM to the user', (done) ->
        saySpy = this.bot.client.say = sinon.spy()
        this.bot.users.get = (nickname, callback) ->
          callback null, {nickname:nickname}
        this.bot.getUser 'someUser', (err, user) ->
          expect(user.pm).to.be.a 'function'
          user.pm 'Some message'
          expect(saySpy).to.be.calledOnce
          expect(saySpy).to.be.calledWith 'someUser', 'Some message'
          done()

    describe 'user#kick(channel, reason)', ->
      it 'should try to kick the user', (done) ->
        sendSpy = this.bot.client.send = sinon.spy()
        this.bot.users.get = (nickname, callback) ->
          callback null, {nickname:nickname}
        this.bot.getUser 'someUser', (err, user) ->
          expect(user.kick).to.be.a 'function'
          user.kick '#pwnies', 'You do not pwn'
          expect(sendSpy).to.be.calledOnce
          expect(sendSpy).to.be.calledWith 'KICK', '#pwnies', 'someUser', 'You do not pwn'
          done()

    describe 'user#setIsAdmin(isAdmin, callback)', ->
      it 'should call UserDB.setIsAdmin', (done) ->
        setAdminSpy = this.bot.users.setIsAdmin = sinon.spy()
        this.bot.users.get = (nickname, callback) ->
          callback null, {nickname:nickname}
        this.bot.getUser 'someUser', (err, user) ->
          expect(user.setIsAdmin).to.be.a 'function'
          callback = ->
          user.setIsAdmin true, callback
          expect(setAdminSpy).to.be.calledOnce
          expect(setAdminSpy).to.be.calledWith 'someUser', true, callback
          done()

    describe 'user#makeAdmin(callback) and user#unmakeAdmin(callback)', ->
      it 'should be synonyms for #setIsAdmin', (done) ->
        this.bot.users.get = (nickname, callback) ->
          callback null, {nickname:nickname}
        this.bot.getUser 'someUser', (err, user) ->
          user.setIsAdmin = setIsAdminSpy = sinon.spy()
          expect(user.makeAdmin).to.be.a 'function'
          expect(user.unmakeAdmin).to.be.a 'function'
          callback = ->
          user.makeAdmin callback
          user.unmakeAdmin callback
          expect(setIsAdminSpy).to.be.calledTwice
          expect(setIsAdminSpy.getCall(0)).to.be.calledWith true, callback
          expect(setIsAdminSpy.getCall(1)).to.be.calledWith false, callback
          done()


  describe 'when a command is received', ->
    plugin =
      commands:
        test: (message) ->

    it "should call the correct plugin", (done) ->
      callbacks = 0
      plugin.commands.test = (message) ->
        done() if (callbacks += 1) >= 2

      this.bot.load 'example', plugin
      this.bot._onPM 'userx', '!test something'
      this.bot._onMessage 'userx', '#hack42', '!test something'

    it 'should trim the command from the text', (done) ->
      callbacks = 0
      plugin.commands.test = (message) ->
        expect(message.text).to.eql 'something'
        expect(message.original).to.eql 'SOMEthing'
        done() if (callbacks += 1) >= 2

      this.bot.load 'example', plugin
      this.bot._onPM 'userx', '!test SOMEthing'
      this.bot._onMessage 'userx', '#hack42', '!test SOMEthing'

    describe 'when config.commandPrefix is set', ->
      it 'should still correctly identify commands', (done) ->
        this.bot.config.commandPrefix = '@'
        callbacks = 0
        plugin.commands.test = (message) ->
          expect(message.text).to.eql 'something'
          done() if (callbacks += 1) >= 2

        this.bot.load 'example', plugin
        this.bot._onPM 'userx', '@test something'
        this.bot._onMessage 'userx', '#hack42', '@test something'

  describe 'when a normal PM is received', ->
    it "should call the plugin's 'pm' event handler", (done) ->
      plugin =
        events:
          pm: (message) -> done()
      this.bot.load 'example', plugin
      this.bot._onPM 'userx', 'something'

  describe 'when a public message is received', ->
    describe 'when it highlights the bot', ->
      it "should call the plugin's 'highlight' event handler", (done) ->
        plugin =
          events:
            highlight: (message) -> done()
        this.bot.load 'example', plugin
        this.bot._onMessage 'userx', '#hack42', 'BoterBot: something'

    describe 'when it mentions the bot', ->
      it "should call the plugin's 'mention' event handler", (done) ->
        plugin =
          events:
            mention: (message) -> done()
        this.bot.load 'example', plugin
        this.bot._onMessage 'userx', '#hack42', 'Something about Boterbot'

    describe "when it's an ordinary message", ->
      it "should call the plugin's 'other' event handler", (done) ->
        plugin =
          events:
            other: (message) -> done()
        this.bot.load 'example', plugin
        this.bot._onMessage 'userx', '#hack42', 'Something about ponies'

  describe 'when a NAMES list is received', ->
    it 'should call UserDB.setChanOp for every user', ->
      this.bot._onNames '#hack42',
        'op1': '@', 'user': ''
      fn = this.bot.users.setChanOp
      expect(fn).to.have.been.calledTwice
      expect(fn.getCall 0).to.have.been.calledWith '#hack42', 'op1', true
      expect(fn.getCall 1).to.have.been.calledWith '#hack42', 'user', false

  describe 'when a MODE notice is received', ->
    describe 'when it sets +o or -o for a user', ->
      it 'should call UserDB.setChanOp', ->
        this.bot._onModeSet '#hack42', 'opuser', 'o', 'user', {}
        this.bot._onModeRemove '#hack42', 'opuser', 'o', 'user', {}
        fn = this.bot.users.setChanOp
        expect(fn).to.have.been.calledTwice
        expect(fn.getCall 0).to.have.been.calledWith '#hack42', 'user', true
        expect(fn.getCall 1).to.have.been.calledWith '#hack42', 'user', false


