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

>  <Someone>: BoterBot: Good morning!
>  <MyBoter>: Good morning to you, too, Someone!
>
>  <Person>: good morning, boter.
>  <MyBoter>: Good morning to you, too, Person!

Note that the `'BoterBot: '` prefix is automatically trimmed from the message, and `message.text` lower cased. The original text (also trimmed, but not decapitalized) can be found in `message.original`.

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
        hello: {
          run: goodMorning,
          help: "Greet BoterBot"
        },
        greet: {
          run: goodMorning,
          help: "Greet BoterBot"
        }
      }
    };

    bot.load(goodMorningPlugin);

And now it listens to commands as well!

>  <Someone>: !greet
>  <MyBoter>: Good morning to you, too, Someone!

Easy as `~3.1415`!

Note: the "help" feature is not yet implemented, but will be tied in with the built-in `!help` command when I get around to writing that.

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
