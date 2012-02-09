require 'fibers'
Future = require 'fibers/future'

#We replace Future's version of Function.prototype.future with our own, but use theirs later.
functionWithFiberReturningFuture = Function::future

module.exports = fibrous = (f) ->
  fiberFn = functionWithFiberReturningFuture.call(f) # handles all the heavy lifting of inheriting an existing fiber when appropriate
  asyncFn = (args...) ->
    callback = args.pop()
    throw new Error("Fibrous method expects a callback") unless callback instanceof Function
    future = fiberFn.apply(@, args)
    future.resolve callback
  asyncFn.__fibrousFutureFn__ = fiberFn
  asyncFn


futureize = (asyncFn) ->
  (args...) ->
    fnThis = @ is asyncFn and global or @

    #don't create unnecessary fibers and futures
    return asyncFn.__fibrousFutureFn__.apply(fnThis, args) if asyncFn.__fibrousFutureFn__

    future = new Future
    args.push(future.resolver())
    try
      asyncFn.apply(fnThis, args)
    catch e
      # ensure synchronous errors are returned via the future
      future.throw(e)
    future

synchronize = (asyncFn) ->
  (args...) ->
    asyncFn.future.apply(@, args).wait()

objectPrototypeProps = {}
objectPrototypeProps[key] = true for key in Object.getOwnPropertyNames(Object::)

proxyAll = (src, target, proxyFn) ->
  for key in Object.keys(src) # Gives back the keys on this object, not on prototypes; ignore any rewrites of toString which can cause problems.
    do (key) ->
      try
        return if typeof src[key] isnt 'function' # getter methods may throw an exception in some contexts
        return if objectPrototypeProps[key]?
      catch e
        return

      target[key] = proxyFn(key)

  target

proxyBuilder = (futureOrSync) ->
  (that) ->
    result =
      if typeof(that) is 'function'
        func = (futureOrSync is 'future' and futureize or synchronize)(that)
        func.__proto__ = Object.getPrototypeOf(that)[futureOrSync] if Object.getPrototypeOf(that) isnt Function.prototype
        func
      else
        Object.create(Object.getPrototypeOf(that) and Object.getPrototypeOf(that)[futureOrSync] or null)

    result.that = that

    proxyAll that, result, (key) ->
      (args...) ->
          #relookup the method every time to pick up reassignments of key on obj or an instance
          @that[key][futureOrSync].apply(@that, args)


defineMemoizedPerInstanceProperty = (target, propertyName, factory) ->
  cacheKey = "__fibrous#{propertyName}__"
  Object.defineProperty target, propertyName,
    enumerable: false
    get: ->
      unless @hasOwnProperty(cacheKey) and @[cacheKey]
        Object.defineProperty @, cacheKey, value: factory(@), enumerable: false # ensure the cached version is not enumerable
      @[cacheKey]


for base in [Object::, Function::]
  defineMemoizedPerInstanceProperty(base, 'future', proxyBuilder('future'))
  defineMemoizedPerInstanceProperty(base, 'sync', proxyBuilder('sync'))


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
