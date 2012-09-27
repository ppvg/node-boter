_Boter_ is a simple library to build your own _smooth_ IRC bot using [node.js](http://nodejs.org). Boter is built on top of [node-irc](https://github.com/martynsmith/node-irc) and written in [CoffeeScript](http://coffeescript.org/). The name (_boter_) is obviously derived from the word "bot", and is Dutch for "butter".

Installation
------------

Clone the repository or copy the files to your path of choice, and then:

    $ cd path/to/boter/
    $ npm install
    $ npm build

This should also install the development dependencies (a necessary evil at this point), so you can check whether everything was installed correctly by running:

    $ npm test

Usage
-----

You can create a _Boter_ bot like your would create a `node_irc` client:

    var boter = require('../path/to/boter/');
    var bot = new boter.Boter('irc.server.foo', 'MyBoter', {channels: [#bar]});

More later on how to actually use the bot.

Testing
-------

For testing, _Boter_ uses [Mocha](http://visionmedia.github.com/mocha/) and [should.js](https://github.com/visionmedia/should.js). In addition, [Mockery](https://github.com/mfncooper/mockery) and [Sinon.JS](http://sinonjs.org/) are used for mocking `node_irc`.

To run the test:

    $ cd path/to/boter/
    $ npm test

Alternatively, you can use `cake test` or run `mocha ./test/` directly.

License
-------

This software is licensed under the Simplified BSD License (see [LICENSE](./LICENSE)).
