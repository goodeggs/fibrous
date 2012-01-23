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
  The wrap method introduces future and sync versions of all the methods in the wrapped object.
  The require method will require a module and wrap it.
  The wait method is a convenience passthrough to Fiber.wait which returns the results of all the futures.
