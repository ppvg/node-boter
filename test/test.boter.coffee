mockery = require 'mockery'
should = require 'should'
mocks = require './mocks'
path = require 'path'

Boter = null

ircMock =
  setup: ->
    mockery.enable()
    mockery.registerAllowables ['../', './lib/Boter', './Message', './regex', 'path']
    mockery.registerMock 'irc', { Client: mocks.IrcClient }
    mockery.registerMock 'builtins', mocks.builtins
    Boter = require '../'
  tearDown: ->
    mockery.deregisterMock 'irc'
    mockery.deregisterMock 'builtins'
    mockery.disable()
    Boter = null


describe 'Boter', ->
  bot = {}
  args =
    server: 'irc.server.foo'
    name: 'BoterBot'
    opts:
      realName: 'Boter, the CoffeeScript bot'
      aliasses: ['Boter', 'MyBoter']

  before ircMock.setup
  after  ircMock.tearDown

  beforeEach ->
    mocks.IrcClient.reset()
    bot = new Boter args.server, args.name, args.opts

  describe 'constructor', ->
    it 'should instantiate an irc.Client', ->
      mocks.IrcClient.calledWithNew().should.be.true

    it 'should keep a list of aliasses', ->
      bot.aliasses.should.eql ['boterbot', 'boter', 'myboter']

    basePath = path.dirname module.filename

    it 'should set a default plugin path relative to the parent module', ->
      # something like "/home/user/projects/Boter/test/plugins"
      bot.config.pluginPath.should.equal path.resolve(basePath, 'plugins')

    it 'should set a default data path relative to the parent module', ->
      # something like "/home/user/projects/Boter/test/data"
      bot.config.dataPath.should.equal path.resolve(basePath, 'data')

    it.skip 'should load the built-in commands', ->
      bot.commands.example.should.equal mocks.builtins.example

  describe 'load plugin', ->
    plugin =
      events:
        highlight: (message) ->
      commands:
        barrelroll:
          help: "Does a barrelroll"
          run: (message) ->
        boter:
          help: "Boter the entire channel"
          run: (message) ->

    it 'should add the plugin to bot.plugins', ->
      numPlugins = bot.plugins.length
      bot.load plugin
      bot.plugins.length.should.equal numPlugins + 1
      bot.plugins[numPlugins].should.equal plugin

    it "should add the plugin's commands to bot.commands", ->
      bot.load plugin
      bot.commands.barrelroll.should.equal plugin.commands.barrelroll
      bot.commands.boter.should.equal plugin.commands.boter

    describe 'when the same plugin is added twice', ->
      it 'should throw an error', ->
        bot.load plugin
        (-> bot.load plugin).should.throw()

  describe 'when a command is received', ->
    plugin =
      commands:
        test:
          help: "meh"
          run: (message) ->

    it "should call the correct plugin's .run()", (done) ->
      callbacks = 0
      plugin.commands.test.run = (message) ->
        done() if (callbacks += 1) >= 2

      bot.load plugin
      bot._onPM 'userx', '!test something'
      bot._onOther 'userx', '#hack42', '!test something'

    it 'should trim the command from the text', (done) ->
      callbacks = 0
      plugin.commands.test.run = (message) ->
        message.text.should.eql 'something'
        message.original.should.eql 'SOMEthing'
        done() if (callbacks += 1) >= 2

      bot.load plugin
      bot._onPM 'userx', '!test SOMEthing'
      bot._onOther 'userx', '#hack42', '!test SOMEthing'

    describe 'when config.commandPrefix is set', ->
      it 'should still correctly identify commands', (done) ->
        bot.config.commandPrefix = '@'
        callbacks = 0
        plugin.commands.test.run = (message) ->
          message.text.should.eql 'something'
          done() if (callbacks += 1) >= 2

        bot.load plugin
        bot._onPM 'userx', '@test something'
        bot._onOther 'userx', '#hack42', '@test something'

  describe 'when a normal PM is received', ->
    it "should call the plugin's 'pm' event handler", (done) ->
      plugin =
        events:
          pm: (message) -> done()
      bot.load plugin
      bot._onPM 'userx', 'something'

  describe 'when a public message is received', ->
    describe 'when it highlights the bot', ->
      it "should call the plugin's 'highlight' event handler", (done) ->
        plugin =
          events:
            highlight: (message) -> done()
        bot.load plugin
        bot._onOther 'userx', '#hack42', 'BoterBot: something'

    describe 'when it mentions the bot', ->
      it "should call the plugin's 'mention' event handler", (done) ->
        plugin =
          events:
            mention: (message) -> done()
        bot.load plugin
        bot._onOther 'userx', '#hack42', 'Something about Boterbot'

    describe "when it's an ordinary message", ->
      it "should call the plugin's 'other' event handler", (done) ->
        plugin =
          events:
            other: (message) -> done()
        bot.load plugin
        bot._onOther 'userx', '#hack42', 'Something about ponies'
