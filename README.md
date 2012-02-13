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
    eg. func.future() or func.sync() (with this as the global object) OR func.future.call(someThis) (with this as someThis).
  future and sync accessors have been added to the Object prototype (correctly, so that they are not enumerable) so that
    you can call attached functions in that style while preserving this: eg. obj.future.func() or obj.sync.func()
  The wait method is a convenience passthrough to Fiber.wait which returns the results of all the futures.
  Requiring fibrous/lib/fiber_spec_helper to ensure each jasmine spec runs inside a fiber.
