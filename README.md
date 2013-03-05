_Boter_ is a simple library to build your own _smooth_ IRC bot using [node.js](http://nodejs.org). It allows you to easily respond to _highlights_, _mentions_ and _PMs_.

Boter is built on top of the excellent [node-irc](https://github.com/martynsmith/node-irc) and written in [CoffeeScript](http://coffeescript.org/). The name (_boter_) is obviously derived from the word "bot" but is also the Dutch word for "butter".


Installation
------------

Installation is as simple as:

    $ npm install boter

If you want to hack on Boter or check if it works correctly on your system you can clone the repository or copy the files to your path of choice, and then:

    $ cd path/to/Boter/
    $ npm install

You can then run the tests by simple calling:

    $ cake test


Usage
-----

You can create a _Boter_ bot like your would create a `node_irc` client:

    var Boter = require('../path/to/Boter/');

    var opts = {
        channels: [#bar]
    };
    var bot = new Boter('irc.server.foo', 'MyBoter', opts);

In addition to the nickname, you can give the bot a few aliasses to which it will respond:

    var opts = {
        channels: [#bar],
        aliasses: ['BoterBot', 'Boter']
    }
    var bot = new Boter('irc.server.foo', 'MyBoter', opts);


### Listening to messages

Now for the fun part: receiving and sending messages. Since version 1.0.0, Boter is plugin-based. It's really easy to write a plugin. For example, here's a simple "Good morning" plugin:

    goodMorning = function(message) {
      if (/^good morning/.test(message.text))
        message.reply("Good morning to you, too, "+message.from+"!");
    }

    goodMorningPlugin = {
      events: {
        highlight: goodMorning,
        mention: goodMorning
      }
    };

Now all you have to do is load the plugin:

    bot.load(goodMorningPlugin);

... and use it!

    <Someone>: BoterBot: Good morning!
    <MyBoter>: Good morning to you, too, Someone!
    
    <Person>: good morning, boter.
    <MyBoter>: Good morning to you, too, Person!

Note that the "BoterBot: " prefix is automatically trimmed from the message, and `message.text` is lower cased. The original text (also trimmed, but not decapitalized) can be found in `message.original`.

BoterBot allows you to listen to three kinds of events:

- `'pm'` event handlers are called when a PM (or "query") is received;
- `'highlight'` when the Bot is specifically adressed, e.g. "BoterBot: hey, you!";
- `'mention'` when the bot is mentioned elsewhere in the message. e.g. "Ceterum censeo boterbot delendam est.".

All of these events pass a `Message` object to the callback, as shown above. Mentions and highlights are triggered on the bot's nick or any of its aliasses, which are matched case insensitively.

### Listening to commands

Boter also supports a command-style system, which is also tied in with the plugin system. A plugin can listen for commands as wel as other types of messages, so you can make your plugins as flexible as you like.

To extend the example from above:

    // goodMorning = function(message) { // ... }

    goodMorningPlugin = {
      events: {
        highlight: goodMorning,
        mention: goodMorning
      },
      commands: {
        hello: goodMorning,
        greet: goodMorning
      }
    };

    bot.load(goodMorningPlugin);

And now it listens to commands as well!

    <Someone>: !greet
    <MyBoter>: Good morning to you, too, Someone!

Easy as `~3.1415`!

### The `message` object

All event and command handlers receive a `message` object. You've already seen `message.text` and `message.reply`. It has a few more properties:

#### `message.text`

The text of the message, converted to lower case. If the message highlights the bot (e.g. "BotNick: how are you?"), the bot's nickname is trimmed from the message (e.g. "how are you?").

#### `message.original`

Not converted to lower case, but otherwise the same as `text`.

#### `message.from`

The user that sent the message. This is a `user` object (see below), so to get the user's nickname, use `message.from.nickname`.

#### `message.context`

Where the message was sent to. This is either the name of a channel (e.g. "#ponies") or the name of a user, depending on whether it was a channel message or a PM.

#### `message.reply(replyText)`

Shortcut to `bot.say(message.context, replyText)`, if you have access to the `bot`. This allows you to easily respond to incoming messages.

If the original message was a PM, `reply` sends a PM back to the sender. If it was a channel message, the `reply` goes to the same channel.


### User management

Known users are saved to a [tiny](https://github.com/chjj/node-tiny) database. As mentioned before, `message.from` contains a special `user` object. It has the following properties:

#### `user.nickname`

The user's nickname. Case sensitive.

#### `user.isRegistered`

Whether the user has his or her nickname registered with NickServ (and is signed on) the last time the bot checked. The bot checks this when it joins and whenever a user joins or changes nickname.

#### `user.hasSudo`

Whether the user was given sudo rights (using `bot.meet(user, cb)`). Only **registered** users can be given sudo rights.

**Note:** if a user was previously given sudo, but someone else is now using his or her nick, `hasSudo` is still true, even though they may not be the same person! On other words: **always check `isRegistered` as well!**.

#### `user.pm(message)`

Shortcut to send the user a PM.

#### `user.kick(channel, [reason])`

Kick the user from the given `channel` for the given `reason` (optional). Only works if the bot has ops status in that channel (obviously).


### Get access to the bot in your plugin

To get access to the bot's methods in your plugin, you could define your plugin in the same file as the bot. But there is a cleaner (and safer) way to get access to some of the bot's features: the `botProxy`.

Instead of returning an `object` as your plugin, return a `function`:

    goodMorningPlugin = function(botProxy) {

      console.log(botProxy)
      // { meet: [Function], forget: [Function], say: [Function] }

      return {
        events:   // ...
        commands: // ...
      }
    }

#### `function meet(nickname, callback)`

Set `hasSudo` to `true` for the user with the given `nickname`. The callback signature is `(err, met)`, where `met` is `true` if the user was successfully given `hasSudo`.

#### `function forget(nickname, callback)`

The inverse of `meet`. The callback signature is `(err)`.

#### `function say(context, message)`

Make the bot say something in the given `context` (which can be a channel, like `#ponies`; or a user, in which case it's a PM).


### Plugin management

At the moment, the `load` command is the only way to manage plugins. I'm still working on an easy-to-use system to load plugins from files, as well as load, unload and reload plugins while the bot is running. Look for that in the next version. :)


Testing
-------

To run the test:

    $ cd path/to/Boter/
    $ cake test

In addition, you can:

 * use `cake build` to build the CoffeeScript source to `lib/`;
 * use `cake watch` to monitor and run the test when they change, or;
 * <s>use `cake coverage` to generate a code coverage report (which is saved to `lib-cov/report.html`).</s> coverage is broken right now because of the switch from `make` to `cake`.

Alternatively, you can use `npm [command]` instead of `cake [command]` (they're equivalent).

**Note:** `jscoverage` is needed to generate a coverage report.

For testing, _Boter_ uses [Mocha][1] and [should.js][2]. In addition, [Mockery][3] and [sinon][4] are used to test in isolation (with a mock of `node_irc`).

[1]: http://visionmedia.github.com/mocha/
[2]: https://github.com/visionmedia/should.js
[3]: https://github.com/mfncooper/mockery
[4]: http://sinonjs.org/


License
-------

This software is licensed under the Simplified BSD License (see [LICENSE](./LICENSE)).
