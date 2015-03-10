Fibrous
=======

Easily mix asynchronous and synchronous programming styles in node.js.

[![build status][travis-badge]][travis-link]
[![npm version][npm-badge]][npm-link]
[![mit license][license-badge]][license-link]
[![we're hiring][hiring-badge]][hiring-link]

Benefits
--------

* Easy-to-follow flow control for both serial and parallel execution
* Complete stack traces, even for exceptions thrown within callbacks
* No boilerplate code for error and exception handling
* Conforms to standard node async API

Install
-------

Fibrous requires node version 0.6.x or greater.

```
npm install fibrous
```


Examples
-----

Would you rather write this:

```javascript
var updateUser = function(id, attributes, callback) {
  User.findOne(id, function (err, user) {
    if (err) return callback(err);
    
    user.set(attributes);
    user.save(function(err, updated) {
      if (err) return callback(err);

      console.log("Updated", updated);
      callback(null, updated);
    });
  });
});
```

Or this, which behaves identically to calling code:

```javascript
var updateUser = fibrous(function(id, attributes) {
  user = User.sync.findOne(id);
  user.set(attributes);
  updated = user.sync.save();
  console.log("Updated", updated);
  return updated;
});
```

Or even better, with [CoffeeScript](http://coffeescript.org):

```coffeescript
updateUser = fibrous (id, attributes) ->
  user = User.sync.findOne(id)
  user.set(attributes)
  updated = user.sync.save()
  console.log("Updated", updated)
  updated
```

### Without Fibrous

Using standard node callback-style APIs without fibrous, we write 
(from [the fs docs](http://nodejs.org/docs/v0.6.14/api/fs.html#fs_fs_readfile_filename_encoding_callback)):

```javascript
fs.readFile('/etc/passwd', function (err, data) {
  if (err) throw err;
  console.log(data);
});
```

### Using sync

Using fibrous, we write:

```javascript
data = fs.sync.readFile('/etc/passwd');
console.log(data);
```

### Using future

This is the same as writing:

```javascript
future = fs.future.readFile('/etc/passwd');
data = future.wait();
console.log(data);
```

### Waiting for Multiple Futures

Or for multiple files read asynchronously:

```javascript
futures = [
  fs.future.readFile('/etc/passwd'),
  fs.future.readFile('/etc/hosts')
];
data = fibrous.wait(futures);
console.log(data[0], data[1]);
```

Note that `fs.sync.readFile` is **not** the same as `fs.readFileSync`. The
latter blocks while the former allows the process to continue while
waiting for the file read to complete.

Make It Fibrous
---------------

Fibrous uses [node-fibers](https://github.com/laverdet/node-fibers)
behind the scenes.

`wait` and `sync` (which uses `wait`
internally) require that they are called within a fiber. Fibrous
provides two easy ways to do this.

### 1. fibrous Function Wrapper

Pass any function to `fibrous` and it returns a function that
conforms to standard node async APIs with a callback as the last
argument. The callback expects `err` as the first argument and the function
result as the second. Any exception thrown will be passed to the
callback as an error.

```javascript
var asynFunc = fibrous(function() {
  return fs.sync.readFile('/etc/passwd');
});
```

is functionally equivalent to:

```javascript
var asyncFunc = function(callback) {
  fs.readFile('/etc/passwd', function(err, data) {
    if (err) return callback(err);

    callback(null, data);
  });
}
```

With coffeescript, the fibrous version is even cleaner:

```coffeescript
asyncFunc = fibrous ->
  fs.sync.readFile('/etc/passwd')
```

`fibrous` ensures that the passed function is
running in an existing fiber (from higher up the call stack) or will
create a new fiber if one does not already exist.

### 2. Express/Connect Middleware

Fibrous provides [connect](http://www.senchalabs.org/connect/)
middleware that ensures that every request runs in a fiber.
If you are using [express](http://expressjs.com/), you'll
want to use this middleware.

```javascript
var express = require('express');
var fibrous = require('fibrous');

var app = express();

app.use(fibrous.middleware);

app.get('/', function(req, res){
  data = fs.sync.readFile('./index.html', 'utf8');
  res.send(data);
});
```

### 3. Wrap-and-run with fibrous.run

`fibrous.run` is a utility function that creates a fibrous function then executes it.

Provide a callback to handle any errors and the return value of the passed function (if you need it).
If you don't provide a callback and there is an error, run will throw the error which will produce an uncaught exception.
That may be okay for quick and dirty work but is probably a bad idea in production code.

```javascript
fibrous.run(function() {
  var data = fs.sync.readFile('/etc/passwd');
  console.log(data.toString());
  return data;
}, function(err, returnValue) {
  console.log("Handle both async and sync errors here", err);
});
```

### 4. Waiting on a callback

Sometimes you need to wait for a callback to happen that does not conform to `err, result` format (for example streams). In this case the following pattern works well:

```javascript
var stream = <your stream>

function wait(callback) {
  stream.on('close', function(code) {
    callback(null, code);
  });
}

var code = wait.sync();
```

Details
-------

### Error Handling / Exceptions

In the above examples, if `readFile` produces an error, the fibrous versions
(both `sync` and `wait`) will throw an exception. Additionally, the stack
trace will include the stack of the calling code unlike exceptions
typically thrown from within callback.


### Testing

Fibrous provides a test helper for [jasmine-node](https://github.com/mhevery/jasmine-node) 
that ensures that `beforeEach`, `it`, and `afterEach` run in a fiber.
Require it in your shared `spec_helper` file or in the spec files where
you want to use fibrous.

```javascript
require('fibrous/lib/jasmine_spec_helper');

describe('My Spec', function() {
  
  it('tests something asynchronous', function() {
    data = fs.sync.readFile('/etc/password');
    expect(data.length).toBeGreaterThan(0);
  });
});
```

If an asynchronous method called through fibrous produces an error, the
spec helper will fail the spec.

[mocha-fibers](https://github.com/tzeskimo/mocha-fibers) provides a fiber wrapper for [mocha](http://mochajs.org/).

If you write a helper for other testing frameworks, we'd love to include it in the project.

### Console

Fibrous makes it much easier to work with asynchronous methods in an
interactive console, or REPL.

If you find yourself in an interactive session, you can require fibrous so that
you can use `future`.

```
> fs = require('fs');
> require('fibrous');
> data = fs.future.readFile('/etc/passwd', 'utf8');
> data.get()
```

In this example, `data.get()` will return the result of the future,
provided you have waited long enough for the future to complete.
(The time it takes to type the next line is almost always long enough.)

You can't use `sync` in the above scenario because a fiber has not been created
so you can't call `wait` on a future.

Fibrous does provide a bin script that creates a new interactive console where each command
is run in a fiber so you can use sync. If you install fibrous with `npm install -g fibrous`
or have `./node_modules/.bin` on your path, you can just run:

```
$ fibrous
Starting fibrous node REPL...
> fs = require('fs');
> data = fs.sync.readFile('/etc/passwd', 'utf8');
> console.log(data);
##
# User Database
#
...
```

Or for a CoffeeScript REPL:

```
$ fibrous -c [or --coffee]
Starting fibrous coffee REPL...
coffee> fs = require 'fs'
coffee> data = fs.sync.readFile '/etc/passwd', 'utf8'
coffee> console.log data
##
# User Database
#
...
```

### Gotchas


The first time you call `sync` or `future` on an object, it builds the sync
and future proxies so if you add a method to the object later, it will
not be proxied.

#### With Express and `bodyParser` or `json`

You might be getting an error in Express that you are not in context of a fiber even after adding `fibrous.middleware` to your stack. This can happen if you added it before `express.json()` or `express.bodyParser()`. Here's an example:

```javascript
// might not work
app.use(fibrous.middleware);
app.use(express.bodyParser());

// or
app.use(fibrous.middleware);
app.use(express.json());

// should work
app.use(express.bodyParser());
app.use(fibrous.middleware);

// or
app.use(express.json());
app.use(fibrous.middleware);
```

Behind The Scenes
-----------------


### Futures

Fibrous uses the `Future` implementation from [node-fibers](https://github.com/laverdet/node-fibers).

`future.wait` waits for the future to resolve then returns the result while allowing the process
to continue. `fibrous.wait` accepts a single future, multiple future arguments or an array of futures.
It returns the result of the future if passed just one, or an array of
results if passed multiple.

`future.get` returns the result of the resolved future or throws an
exception if not yet resolved.

### Object & Function mixins

Fibrous mixes `future` and `sync` into `Function.prototype` so you can
use them directly as in:

```javascript
readFile = require('fs').readFile;
data = readFile.sync('/etc/passwd');
```

Fibrous adds `future` and `sync` to `Object.prototype` correctly so they
are not enumerable.

These proxy methods also ignore all getters, even those that may
return functions. If you need to call a getter with fibrous that returns an
asynchronous function, you can do:

```javascript
func = obj.getter
func.future.call(obj, args)
```

### Disclaimer

Some people don't like libraries that mix in to Object.prototype
and Function.prototype. If that's how you feel, then fibrous is probably
not for you. We've been careful to mix in 'right' so that we don't
change property enumeration and find that the benefits of having sync
and future available without explicitly wrapping objects or functions
are worth the philosophical tradeoffs.


Contributing
------------

```
git clone git://github.com/goodeggs/fibrous.git
npm install
npm test
```

Fibrous is written in [coffeescript](http://coffeescript.org) with
source in `src/` compiled to `lib/`.

Tests are written with [jasmine-node](https://github.com/mhevery/jasmine-node) in `spec/`.

Run tests with `npm test` which will also compile the coffeescript to
`lib/`.

Pull requests are welcome. Please provide tests for your changes and
features. Thanks!

Contributors
------------

* Randy Puro ([randypuro](https://github.com/randypuro))
* Alon Salant ([asalant](https://github.com/asalant))
* Bob Zoller ([bobzoller](https://github.com/bobzoller))

[travis-badge]: http://img.shields.io/travis/goodeggs/fibrous/master.svg?style=flat-square
[travis-link]: https://travis-ci.org/goodeggs/fibrous
[npm-badge]: http://img.shields.io/npm/v/fibrous.svg?style=flat-square
[npm-link]: https://www.npmjs.org/package/fibrous
[license-badge]: http://img.shields.io/badge/license-mit-blue.svg?style=flat-square
[license-link]: LICENSE.md
[hiring-badge]: https://img.shields.io/badge/we're_hiring-yes-brightgreen.svg?style=flat-square
[hiring-link]: http://goodeggs.jobscore.com/?detail=Open+Source&sid=161
