_Boter_ is a simple library to build your own _smooth_ IRC bot using [node.js](http://nodejs.org). Boter is built on top of [node-irc](https://github.com/martynsmith/node-irc) and written in [CoffeeScript](http://coffeescript.org/). The name (_boter_) is obviously derived from the word "bot", and is Dutch for "butter".

Installation
------------

Clone the repository or copy the files to your path of choice, and then:

    $ cd path/to/boter/
    $ npm install
    $ npm build

This should also install the development dependencies (a necessary evil at this point), so you can check whether everything was installed correctly by running:

    $ make test

_(Or `npm test`.)_

Usage
-----

You can create a _Boter_ bot like your would create a `node_irc` client:

    var boter = require('../path/to/boter/');
    var bot = new boter.Boter('irc.server.foo', 'MyBoter', {channels: [#bar]});

More later on how to actually use the bot.

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

For testing, _Boter_ uses [Mocha](http://visionmedia.github.com/mocha/) and [should.js](https://github.com/visionmedia/should.js). In addition, [Mockery](https://github.com/mfncooper/mockery) and [Sinon.JS](http://sinonjs.org/) are used for mocking `node_irc`.

License
-------

This software is licensed under the Simplified BSD License (see [LICENSE](./LICENSE)).
