examplePlugin = (proxy) ->

  bot = proxy
  bot.say '#hack42', 'blah'
  bot.kick 'userx'

  events =
    #            #
    # IDEAS:     #
    #            #
    # like this: #
    #            #
    highlight:
      test: (message) ->
        # regex match or whatever
        # returns boolean
      handle: (message) ->
        # handle the response
        # can be async

    #               #
    # or like this: #
    #               #
    pm: (message) ->
      # regex to see if action is needed,
      # can be async

  commands =
    example:
      run: (message) ->
        # handle command
      help: """
        help message
        can be multiline
      """

  return plugin =
    events: events
    commands: commands
