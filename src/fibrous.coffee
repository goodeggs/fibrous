require 'fibers'
Future = require 'fibers/future'
#logger = require './logger'



#Function.prototype.fibrous = (that, args...) ->
#  f = @
#  futureF = Future.wrap(f)
#  futureF.apply(that, args)
#
module.exports = fibrous = (f) ->
#  futureF = f.future()
#  (args...) ->
#    if Fiber.current
#      return futureF.apply(@, args)
#    else
#      callback = args.pop()
#      throw new Error("running #{futureF} outside of a Fiber, so expected a callback") unless callback instanceof Function
#      future = futureF.apply(@, args)
#      future.resolve (err, result) ->
#        # Ensure the callback is called outside the fiber (to avoid switching to fibrous versions of method calls from the async expecting callback)
#        process.nextTick ->
#          callback(err, result)

fibrous.wrap = (obj) ->
  return obj if obj.__fibrouswrapped__

  for attr in ['sync', 'future']
    throw new Error("the object to wrap already has a .#{attr} attribute [#{obj[attr]}]") if obj[attr]?

  obj.__fibrouswrapped__ = true
  obj.future = {}
  obj.sync = {}

  for key, fn of obj when typeof fn == 'function'
    do (key) ->
      obj.future[key] = (args...) ->
        future = new Future
        args.push(future.resolver())
        #relookup the method every time to pick up reassignments of key on obj
        obj[key].apply(obj, args)
        future

      obj.sync[key] = (args...) ->
        obj.future[key](args...).wait()

  obj

fibrous.require = (modName) ->
  result = require modName
  fibrous.wrap result
  result

#
## Run the subsequent steps in a Fiber (at least until some non-cooperative async operation)
#fibrous.middleware = (req, res, next) ->
#  process.nextTick ->
#    Fiber ->
#      try
#        next()
#      catch e
#        # We expect any errors which bubble up the fiber will be handled by the router
#        logger.error('Unexpected error bubble up to the top of the fiber', e)
#    .run()
#
#fibrous.wait = (futures...) ->
#  Future.wait(futures...)
#  future.get() for future in futures # return an array of the results

