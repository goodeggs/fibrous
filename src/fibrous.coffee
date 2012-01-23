require 'fibers'
Future = require 'fibers/future'

module.exports = fibrous = (f) ->
  futureFn = f.future() # handles all the heavy lifting of inheriting an existing fiber when appropriate
  asyncFn = (args...) ->
    callback = args.pop()
    throw new Error("Fibrous method expects a callback") unless callback instanceof Function
    future = futureFn.apply(@, args)
    future.resolve callback
  asyncFn.__fibrousFutureFn__ = futureFn
  asyncFn


fibrous.wrap = (obj) ->
  return obj if obj.__fibrouswrapped__

  throw new Error("the object to wrap already has a .sync attribute [#{obj.sync}]") if obj.sync?

  # When wrapping functions, we just attach our methods ro node-fibers Function prototype future method.
  if obj.future? and obj.future != Function.prototype.future
    throw new Error("the object to wrap already has a .future attribute [#{obj.future}]")

  obj.__fibrouswrapped__ = true
  obj.future ?= {}
  obj.sync = {}

  for key, fn of obj when typeof fn == 'function'
    do (key) ->
      obj.future[key] = (args...) ->
        #relookup the method every time to pick up reassignments of key on obj
        fn = obj[key]

        #don't create unnecessary fibers and futures
        return fn.__fibrousFutureFn__.apply(obj, args) if fn.__fibrousFutureFn__

        future = new Future
        args.push(future.resolver())
        fn.apply(obj, args)
        future

      obj.sync[key] = (args...) ->
        obj.future[key](args...).wait()
  obj


fibrous.require = (modName) ->
  result = require modName
  fibrous.wrap result
  result


fibrous.wait = (futures...) ->
  getResults = (futureOrArray) ->
    return futureOrArray.get() if (futureOrArray instanceof Future)
    getResults(i) for i in futureOrArray

  Future.wait(futures...)
  result = getResults(futures) # return an array of the results
  result = result[0] if result.length == 1
  result


# Run the subsequent steps in a Fiber (at least until some non-cooperative async operation)
fibrous.middleware = (req, res, next) ->
  process.nextTick ->
    Fiber ->
      try
        next()
      catch e
        # We expect any errors which bubble up the fiber will be handled by the router
        console.error('Unexpected error bubble up to the top of the fiber:', e?.stack or e)
    .run()

fibrous.specHelper = require('./fiber_spec_helper')
