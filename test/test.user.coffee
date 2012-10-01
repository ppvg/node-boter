describe 'User', ->
  User = {}

  before ->
    {User} = require '../'

  describe '#equals()', ->
    describe 'when users have the same username and host', ->
      it 'should return true', ->
        user1 = new User 'user', 'some.host.foo'
        user2 = new User 'user', 'some.host.foo'
        user1.equals(user2).should.be.true

    describe 'when users have different username', ->
      it 'should return false', ->
        user1 = new User 'user', 'some.host.foo'
        user2 = new User 'other', 'some.host.foo'
        user1.equals(user2).should.be.false

    describe 'when users have different hostname', ->
      it 'should return false', ->
        user1 = new User 'user', 'some.host.foo'
        user2 = new User 'user', 'some.other.foo'
        user1.equals(user2).should.be.false
