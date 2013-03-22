# NB: Some modules are included via test/common.js
domain = require 'domain'

boter = null
loadMock = (tinyMock) ->
  boter =
    UserDB: (sandbox.require libPath + 'UserDB', requires: {tiny: tinyMock})

describe 'UserDB', ->
  describe 'when creating the DB fails', ->
    before -> loadMock mocks.tinyBad
    beforeEach -> mocks.tinySpy.reset()

    describe '#constructor', ->
      it "should emit an 'error' event", (done) ->
        db = new boter.UserDB 'filename'
        db.on 'error', (err) ->
          expect(err).to.be.an.instanceof Error
          done()

    describe '#get', ->
      it 'should return a user object with default values', (done) ->
        db = new boter.UserDB 'filename'
        errorThrown = false
        db.on 'error', (err) -> errorThrown = true

        db.get 'user', (err, user) ->
          expect(err).not.to.exist
          expect(user).to.be.a.object
          expect(user.isRegistered).to.be.false
          expect(user.chanOp).to.be.empty

          process.nextTick ->
            expect(errorThrown).to.be.true
            done()

  describe 'when the DB can be successfully created', ->
    before -> loadMock mocks.tinyGood
    beforeEach ->
      mocks.tinySpy.reset()
      mocks.tinySpy.each = (each, done) -> done()
      mocks.tinySpy.compact = (cb) -> cb()

    describe '#constructor', ->
      it "should emit a 'load' event", (done) ->
        db = new boter.UserDB 'filename'
        db.on 'load', (arg) ->
          expect(arg).to.equal 'cookies'
          done()

      it 'should call #compact() on the Tiny db', (done) ->
        domain.create().run ->
          mocks.tinySpy.compact = sinon.spy()
          db = new boter.UserDB 'filename'
          process.nextTick ->
            expect(mocks.tinySpy.compact).to.be.calledOnce
            done()

      it "should ensure isRegistered is false and chanOp is empty for all users", (done) ->
        domain.create().run ->
          users = [
            { nickname: 'user0', isRegistered: true, chanOp: ['#channel'] }
            { nickname: 'user1', isRegistered: true, chanOp: ['#otherChannel'] }
            { nickname: 'user2', isRegistered: false }
            { nickname: 'user3', isRegistered: false, chanOp: [] } # doesn't need update
          ]
          mocks.tinySpy.each = (each, done) ->
            each users[i] for i in [0..2]
            done()
          calls = 0
          mocks.tinySpy.update = (nickname, props, callback) ->
            expect(nickname).to.equal 'user'+calls
            expect(nickname).to.not.equal 'user3'
            expect(props.isRegistered).to.be.false
            expect(props.chanOp).to.be.empty
            calls += 1
            callback null
          db = new boter.UserDB 'filename'
          process.nextTick ->
            expect(calls).to.equal 3
            done()

    describe '#get', ->
      it 'should get the user from the tiny DB', (done) ->
        db = new boter.UserDB 'filename'
        mocks.tinySpy.get = (nickname, callback) ->
          expect(nickname).to.equal 'user'
          callback null, {}
        db.get 'user', (err, user) ->
          expect(err).to.not.exist
          expect(user).to.be.a.object
          done()

      describe 'user#is()', ->
        describe "is('op')", ->
          it "should throw error 'No channel specified'", (done) ->
            db = new boter.UserDB 'filename'
            mocks.tinySpy.get = (nickname, callback) ->
              callback null, {}
            db.get 'user', (err, user) ->
              expect(-> user.is 'op').to.throw()
              done()

        describe "is('op', '#channel')", ->
          describe 'when the user is chanop', ->
            it 'should return true', (done) ->
              db = new boter.UserDB 'filename'
              mocks.tinySpy.get = (nickname, callback) ->
                callback null, chanOp: ['#pwnies']
              db.get 'user', (err, user) ->
                expect(user.is 'op', '#pwnies').to.be.true
                done()

          describe 'when the user is not chanop', ->
            it 'should return true', (done) ->
              db = new boter.UserDB 'filename'
              mocks.tinySpy.get = (nickname, callback) ->
                callback null, chanOp: ['#pwnies_are_lame']
              db.get 'user', (err, user) ->
                expect(user.is 'op', '#pwnies').to.be.false
                done()

        describe "is('registered', callback)", ->
          describe 'when user.isRegistered is false', ->
            it 'should check NickServ', (done) ->
              bot = checkNickServ: (nickname, callback) ->
                expect(nickname).to.equal 'user'
                callback true
              db = new boter.UserDB 'filename', bot
              mocks.tinySpy.get = (nickname, callback) ->
                callback null, isRegistered: false
              db.get 'user', (err, user) ->
                user.is 'registered', (isRegistered) ->
                  expect(isRegistered).to.be.true
                  done()

          describe 'when no callback is given', ->
            it 'should still check NickServ', (done) ->
              bot = checkNickServ: (nickname, callback) ->
                callback true
                done()
              db = new boter.UserDB 'filename', bot
              mocks.tinySpy.get = (nickname, callback) ->
                callback null, isRegistered: false
              db.get 'user', (err, user) ->
                user.is 'registered'

          describe 'when user.isRegistered', ->
            it "should not check NickServ'", (done) ->
              checkNickServCalled = false
              bot =
                checkNickServ: (nickname, callback) ->
                  checkNickServCalled = true
                  callback true
              db = new boter.UserDB 'filename', bot
              mocks.tinySpy.get = (nickname, callback) ->
                callback null, isRegistered: true
              db.get 'user', (err, user) ->
                user.is 'registered', (isRegistered) ->
                  expect(isRegistered).to.be.true
                  expect(checkNickServCalled).to.be.false
                  done()

        describe "is('admin', callback)", ->
          describe 'when user.isAdmin and user.isRegistered', ->
            it "should call the callback with result 'true'", (done) ->
              db = new boter.UserDB 'filename'
              mocks.tinySpy.get = (nickname, callback) ->
                callback null, isRegistered: true, isAdmin: true
              db.get 'user', (err, user) ->
                user.is 'admin', (isAdmin) ->
                  expect(isAdmin).to.be.true
                  done()

          describe 'when user.isAdmin but not user.isRegistered', ->
            it 'should check NickServ', (done) ->
              nickServChecked = false
              bot = checkNickServ: (nickname, callback) ->
                nickServChecked = true
                callback true
              db = new boter.UserDB 'filename', bot
              mocks.tinySpy.get = (nickname, callback) ->
                callback null, isRegistered: false, isAdmin: true
              db.get 'user', (err, user) ->
                user.is 'admin', (isAdmin) ->
                  expect(nickServChecked).to.be.true
                  expect(isAdmin).to.be.true
                  done()

          describe 'when not user.isAdmin', ->
            it "should not check NickServ", (done) ->
              checkNickServCalled = false
              bot = checkNickServ: (nickname, callback) ->
                checkNickServCalled = true
                callback false
              db = new boter.UserDB 'filename', bot
              mocks.tinySpy.get = (nickname, callback) ->
                callback null, {isRegistered: false, isAdmin: false}
              db.get 'user', (err, user) ->
                user.is 'admin', (isAdmin) ->
                  expect(isAdmin).to.be.false
                  expect(checkNickServCalled).to.be.false
                  done()

    describe '#forget', ->
      it 'should remove the user from the tiny DB', (done) ->
        db = new boter.UserDB 'filename'
        error = {not: 'really'}
        mocks.tinySpy.remove = (nickname, callback) ->
          callback error
        db.forget 'user', (err) ->
          expect(err).to.equal error
          done()

    describe '#setChanOp', ->
      describe 'when setting true', ->
        describe 'when user exists', ->
          it 'should add the channel to user.chanOp', (done) ->
            db = new boter.UserDB 'filename'
            mocks.tinySpy.get = (nickname, callback) ->
              callback null, chanOp: []

            updateCalled = false
            mocks.tinySpy.update = (nickname, props, callback) ->
              expect(props.chanOp[0]).to.equal '#hack42'
              updateCalled = true
              callback null

            db.setChanOp '#hack42', 'user', true, (err) ->
              expect(updateCalled).to.be.true
              expect(err).to.not.exist
              done()

        describe "when user doesn't exist", ->
          it 'should create a new user with the channel in user.chanOp', (done) ->
            db = new boter.UserDB 'filename'
            mocks.tinySpy.get = (nickname, callback) ->
              callback new Error 'No such user or whatever'

            setCalled = false
            mocks.tinySpy.set = (nickname, user, callback) ->
              expect(user.nickname).to.equal nickname
              expect(user.chanOp[0]).to.equal '#hack42'
              setCalled = true
              callback null

            db.setChanOp '#hack42', 'user', true, (err) ->
              expect(setCalled).to.be.true
              expect(err).to.not.exist
              done()

      describe 'when setting false', ->
        describe "when the user exists", ->
          it 'should remove the channel from user.chanOp', (done) ->
            db = new boter.UserDB 'filename'
            mocks.tinySpy.get = (nickname, callback) ->
              callback null, chanOp: ['#hack42']

            updateCalled = false
            mocks.tinySpy.update = (nickname, props, callback) ->
              expect(props.chanOp).to.be.empty
              updateCalled = true
              callback null

            db.setChanOp '#hack42', 'user', false, (err) ->
              expect(updateCalled).to.be.true
              expect(err).to.not.exist
              done()

        describe "when the user doesn't exist", ->
          it 'should do nothing', (done) ->
            db = new boter.UserDB 'filename'
            mocks.tinySpy.get = (nickname, callback) ->
              callback new Error 'No such user or whatever'

            called = false
            call = (nick, user, callback) ->
              called = true
              callback null
            mocks.tinySpy.set = call
            mocks.tinySpy.update = call

            db.setChanOp '#hack42', 'user', false, (err) ->
              expect(called).to.be.false
              expect(err).to.not.exist
              done()

    createTestPropertyShouldBeUpdated = (property, funcName, startVal, endVal) ->
      return (done) ->
        db = new boter.UserDB 'filename'
        mocks.tinySpy.get = (nickname, callback) ->
          user = {}
          user[property] = startVal
          callback null, user

        updateCalled = false
        mocks.tinySpy.update = (nickname, props, callback) ->
          expect(props[property]).to.equal endVal
          updateCalled = true
          callback null

        db[funcName] 'user', true, (err) ->
          expect(updateCalled).to.be.true
          expect(err).to.not.exist
          done()

    createTestUserShouldBeCreated = (property, funcName, val) ->
      return (done) ->
        db = new boter.UserDB 'filename'
        mocks.tinySpy.get = (nickname, callback) ->
          callback new Error 'No such user or whatever'

        setCalled = false
        mocks.tinySpy.set = (nickname, user, callback) ->
          expect(user.nickname).to.equal nickname
          expect(user[property]).to.equal val
          setCalled = true
          callback null

        db[funcName] 'user', val, (err) ->
          expect(setCalled).to.be.true
          expect(err).to.not.exist
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

