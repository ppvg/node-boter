mockery = require 'mockery'
should = require 'should'
sinon = require 'sinon'
domain = require 'domain'

mocks = require './mocks'

describe 'UserDB', ->
  before -> mockery.enable()
  after  -> mockery.disable()

  UserDB = null
  loadUserDB = (tinyMock) ->
    mockery.registerAllowables ['../lib/UserDB', 'events', './regex'], true
    mockery.registerMock 'tiny', tinyMock
    UserDB = require '../lib/UserDB'


  describe 'when creating the DB fails', ->
    before -> loadUserDB mocks.tinyBad
    after  -> mockery.deregisterAll()
    beforeEach -> mocks.tinyspy.reset()

    describe '#constructor', ->
      it "should emit an 'error' event", (done) ->
        db = new UserDB 'filename'
        db.on 'error', (err) ->
          err.should.be.an.instanceof Error
          done()

    describe '#get', ->
      it 'should return a user object with default values', (done) ->
        db = new UserDB 'filename'
        errorThrown = false
        db.on 'error', (err) -> errorThrown = true

        db.get 'user', (err, user) ->
          should.not.exist err
          user.should.be.a.object
          user.isRegistered.should.be.false
          user.chanOp.should.be.empty
          process.nextTick ->
            errorThrown.should.be.true
            done()

  describe 'when the DB can be successfully created', ->
    before -> loadUserDB mocks.tinyGood
    after  -> mockery.deregisterAll()
    beforeEach ->
      mocks.tinyspy.reset()
      mocks.tinyspy.each = ->
      mocks.tinyspy.compact = (cb) -> cb()

    describe '#constructor', ->
      it "should emit a 'load' event", (done) ->
        db = new UserDB 'filename'
        db.on 'load', ->
          done()

      it 'should call #compact() on the Tiny db', (done) ->
        domain.create().run ->
          mocks.tinyspy.compact = sinon.spy()
          db = new UserDB 'filename'
          process.nextTick ->
            mocks.tinyspy.compact.calledOnce.should.be.true
            done()

      it "should ensure isRegistered is false and chanOp is empty for all users", (done) ->
        domain.create().run ->
          users = [
            { nickname: 'user0', isRegistered: true, chanOp: ['#channel'] }
            { nickname: 'user1', isRegistered: true, chanOp: ['#otherChannel'] }
            { nickname: 'user2', isRegistered: false }
            { nickname: 'user3', isRegistered: false, chanOp: [] } # doesn't need update
          ]
          mocks.tinyspy.each = (each, done) ->
            each users[i] for i in [0..2]
            done()
          calls = 0
          mocks.tinyspy.update = (nickname, props, callback) ->
            nickname.should.equal 'user'+calls
            nickname.should.not.equal 'user3'
            props.isRegistered.should.be.false
            props.chanOp.should.be.empty
            calls += 1
            callback null
          db = new UserDB 'filename'
          process.nextTick ->
            calls.should.equal 3
            done()

    describe '#get', ->
      it 'should get the user from the tiny DB', (done) ->
        db = new UserDB 'filename'
        mocks.tinyspy.get = (nickname, callback) ->
          callback null, {}
        db.get 'user', (err, user) ->
          should.not.exist err
          user.should.be.a.object
          done()

    describe '#forget', ->
      it 'should remove the user from the tiny DB', (done) ->
        db = new UserDB 'filename'
        error = {not: 'really'}
        mocks.tinyspy.remove = (nickname, callback) ->
          callback error
        db.forget 'user', (err) ->
          err.should.equal error
          done()

    describe '#setChanOp', ->
      describe 'when setting true', ->
        describe 'when user exists', ->
          it 'should add the channel to user.chanOp', (done) ->
            db = new UserDB 'filename'
            mocks.tinyspy.get = (nickname, callback) ->
              callback null, chanOp: []

            updateCalled = false
            mocks.tinyspy.update = (nickname, props, callback) ->
              props.chanOp[0].should.equal '#hack42'
              updateCalled = true
              callback null

            db.setChanOp '#hack42', 'user', true, (err) ->
              updateCalled.should.be.true
              should.not.exist err
              done()

        describe "when user doesn't exist", ->
          it 'should create a new user with the channel in user.chanOp', (done) ->
            db = new UserDB 'filename'
            mocks.tinyspy.get = (nickname, callback) ->
              callback new Error 'No such user or whatever'

            setCalled = false
            mocks.tinyspy.set = (nickname, user, callback) ->
              user.nickname.should.equal nickname
              user.chanOp[0].should.equal '#hack42'
              setCalled = true
              callback null

            db.setChanOp '#hack42', 'user', true, (err) ->
              setCalled.should.be.true
              should.not.exist err
              done()

      describe 'when setting false', ->
        describe "when the user exists", ->
          it 'should remove the channel from user.chanOp', (done) ->
            db = new UserDB 'filename'
            mocks.tinyspy.get = (nickname, callback) ->
              callback null, chanOp: ['#hack42']

            updateCalled = false
            mocks.tinyspy.update = (nickname, props, callback) ->
              props.chanOp.should.be.empty
              updateCalled = true
              callback null

            db.setChanOp '#hack42', 'user', false, (err) ->
              updateCalled.should.be.true
              should.not.exist err
              done()

        describe "when the user doesn't exist", ->
          it 'should do nothing', (done) ->
            db = new UserDB 'filename'
            mocks.tinyspy.get = (nickname, callback) ->
              callback new Error 'No such user or whatever'

            called = false
            call = (nick, user, callback) ->
              called = true
              callback null
            mocks.tinyspy.set = call
            mocks.tinyspy.update = call

            db.setChanOp '#hack42', 'user', false, (err) ->
              called.should.be.false
              should.not.exist err
              done()

    createTestPropertyShouldBeUpdated = (property, funcName, startVal, endVal) ->
      return (done) ->
        db = new UserDB 'filename'
        mocks.tinyspy.get = (nickname, callback) ->
          user = {}
          user[property] = startVal
          callback null, user

        updateCalled = false
        mocks.tinyspy.update = (nickname, props, callback) ->
          props[property].should.equal endVal
          updateCalled = true
          callback null

        db[funcName] 'user', true, (err) ->
          updateCalled.should.be.true
          should.not.exist err
          done()

    createTestUserShouldBeCreated = (property, funcName, val) ->
      return (done) ->
        db = new UserDB 'filename'
        mocks.tinyspy.get = (nickname, callback) ->
          callback new Error 'No such user or whatever'

        setCalled = false
        mocks.tinyspy.set = (nickname, user, callback) ->
          user.nickname.should.equal nickname
          user[property].should.equal val
          setCalled = true
          callback null

        db[funcName] 'user', val, (err) ->
          setCalled.should.be.true
          should.not.exist err
          done()

    describe '#setIsRegistered', ->
      describe "when the user exists", ->
        it 'it should be updated with isRegistered true',
          createTestPropertyShouldBeUpdated 'isRegistered', 'setIsRegistered', false, true

      describe "when the user doesn't exist", ->
        it 'should be created with isRegistered true',
          createTestUserShouldBeCreated 'isRegistered', 'setIsRegistered', true

    describe '#setIsAdmin', ->
      describe 'when the user exists', ->
        it 'it should be updated with isAdmin true',
          createTestPropertyShouldBeUpdated 'isAdmin', 'setIsAdmin', false, true
      describe "when the user doesn't exist", ->
        it 'should be created with isAdmin true',
          createTestUserShouldBeCreated 'isAdmin', 'setIsAdmin', true

