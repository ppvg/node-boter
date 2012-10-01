_Boter_ is a simple library to build your own _smooth_ IRC bot using [node.js](http://nodejs.org). It allows you to easily respond to _highlights_, _mentions_ and _PMs_.

Boter is built on top of the excellent [node-irc](https://github.com/martynsmith/node-irc) and written in [CoffeeScript](http://coffeescript.org/). The name (_boter_) is obviously derived from the word "bot", and is Dutch for "butter".


Installation
------------

Installation is as simple as:

    $ npm install boter

If you want to hack on Boter or check if it works correctly on your system you can clone the repository or copy the files to your path of choice, and then:

    $ cd path/to/boter/
    $ npm install

You can then run the tests by simple calling:

    $ make test


Usage
-----

You can create a _Boter_ bot like your would create a `node_irc` client:

    var boter = require('../path/to/boter/');

    var opts = {
        channels: [#bar]
    };
    var bot = new boter.Boter('irc.server.foo', 'MyBoter', opts);

In addition to the nickname, you can give the bot a few aliasses to which it will respond:

    var opts = {
        channels: [#bar],
        aliasses: ['BoterBot', 'Boter']
    }
    var bot = new boter.Boter('irc.server.foo', 'MyBoter', opts);

To actually listen to messages, Boter emits events you can listen to:

    var goodMorning = function(message) {
        if (/^good morning/.test(message.text))
            message.reply("Good morning to you, too, "+message.from+"!");
    }
    bot.on('highlight', goodMorning);
    bot.on('mention', goodMorning);

    // <Someone>: BoterBot: Good morning!
    // <MyBoter>: Good morning to you, too, Someone!

    // <Person>: good morning, boter.
    // <MyBoter>: Good morning to you, too, Person!

Note that the `'BoterBot: '` prefix is automatically trimmed from the message, and `message.text` lower cased. The original text (also trimmed, but not decapitalized) can be found in `message.original`.

BoterBot emits three kinds of events:

- It emits `'pm'` when a PM (or "query") is received;
- It emits `'highlight'` when the Bot is specifically adressed, e.g. "BoterBot: hey, you!";
- It emits `'mention'` when the bot is mentioned elsewhere in the message. e.g. "Ceterum censeo boterbot delendam est.".

All of these events pass a `Message` object to the callback, as shown above. Mentions and highlights are triggered on the bot's nick or any of its aliasses, which are matched case insensitively.

More events will follow in a future version (as well as forwarding of all other `node-irc` events).


Testing
-------

To run the test:

    $ cd path/to/boter/
    $ make test

In addition, you can:

 * use `make build` to build the CoffeeScript source to `lib/`;
 * use `make monitor` to monitor and run the test when they change, or;
 * use `make coverage` to generate a code coverage report (which is saved to `lib-cov/report.html`).

Alternatively, you can use `npm [command]` instead of `make [command]` (they're equivalent).

**Note:** `jscoverage` is needed to generate a coverage report.

For testing, _Boter_ uses [Mocha](http://visionmedia.github.com/mocha/) and [should.js](https://github.com/visionmedia/should.js). In addition, [Mockery](https://github.com/mfncooper/mockery) is used to test in isolation (with a mock of `node_irc`).


License
-------

This software is licensed under the Simplified BSD License (see [LICENSE](./LICENSE)).
