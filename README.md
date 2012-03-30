fibrous
======

This node.js module provides an abstraction and convention for using fibers.

install
------
    npm install fibrous

usage
------

  The basic assumption is that all services will be have a standard node style asynchronous api.
  The fibrous prefix method can used to write a method which runs in a fiber (either inheriting, or spawning
    it's own), but which still has the standard node style async external interface.
  future and sync methods have been added to the Function prototype, allowing you to call the function in that style:
    eg. func.future() or func.sync() (with this as the global object) OR func.future(args).
  future and sync accessors have been added to the Object prototype (correctly, so that they are not enumerable) so that
    you can call attached functions in that style while preserving this: eg. obj.future.func() or obj.sync.func()
  The wait method is a convenience passthrough to Fiber.wait which returns the results of all the futures.
  Requiring fibrous/lib/jasmine_spec_helper to ensure each jasmine spec runs inside a fiber.


Why: short explanation w/ link to more detail
Simple way to mix sync and async styles
Easy to use
All APIs are standard node callback style for consistency with internal
and external code

Exception:
  Stack traces easier to capture
  Not hanging responses to user

Usage examples:

Static, instance methods
Connect middleware
Console future
Sync, future
Waiting for a collection of futures
fibrous methods / API strategy

Testing:

jasmine-node support

Fibers
We're using Fibers' Future implementation

Alternatives:


Contributing:

Details:

Disclaimer about extending Object.prototype

Gotchas:
The first time you call sync or future on an object, it builds the sync
and future proxies so if you add a method to the object later, it will
not be proxied (but we could implement a reset to do that).

We ignore getters, even those that may return functions, you could call
func = obj.getter
func.future.call(obj, args)


Blog Post:

How we got to feeling fibrous is a good solution for node:
async module
async article

