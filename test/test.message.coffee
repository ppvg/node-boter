describe 'Message', ->
  Message = {}
  text = "This is some Random Message with Important Capalization."
  message = {}

  before ->
    {Message} = require '../'

  beforeEach ->
    message = new Message 'user', 'context', text

  it 'should store unmodified message in this.original', ->
    message.original.should.equal text

  it 'should store decapitalized message in this.text', ->
    message.text.should.equal text.toLowerCase()
