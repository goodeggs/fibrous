Fiber = require 'fibers'
Future = require 'fibers/future'

# We replace Future's version of Function.prototype.future with our own.
# Keep a reference so we can use theirs later.
functionWithFiberReturningFuture = Function::future

module.exports = fibrous = (fn) ->
  futureFn = functionWithFiberReturningFuture.call(fn) # handles all the heavy lifting of inheriting an existing fiber when appropriate
  # Don't use (args...) here because asyncFn.length == 0 when we do.
  # A common (albeit short-sighted) pattern used in node.js code is checking
  # Fn.length > 0 to determine if a function is async (accepts a callback).
  asyncFn = (cb) ->
    args = if 1 <= arguments.length then Array.prototype.slice.call(arguments, 0) else []
    callback = args.pop()
    throw new Error("Fibrous method expects a callback") unless callback instanceof Function
    future = futureFn.apply(@, args)
    future.resolve callback
  Object.defineProperty asyncFn, '__fibrousFn__', value: fn, enumerable: false
  Object.defineProperty asyncFn, '__fibrousFutureFn__', value: futureFn, enumerable: false
  asyncFn.toString = -> "fibrous(#{fn.toString()})"
  asyncFn


futureize = (asyncFn) ->
  (args...) ->
    fnThis = @ is asyncFn and global or @

    # Don't create unnecessary fibers and futures
    return asyncFn.__fibrousFutureFn__.apply(fnThis, args) if asyncFn.__fibrousFutureFn__

    future = new Future()
    args.push(future.resolver())
    try
      asyncFn.apply(fnThis, args)
    catch e
      # Ensure synchronous errors are returned via the future
      future.throw(e)
    future

synchronize = (asyncFn) ->
  (args...) ->
    # When calling a fibrous function synchronously, we don't need to create a future
    return asyncFn.__fibrousFn__.apply(@ is asyncFn and global or @, args) if asyncFn.__fibrousFn__

    asyncFn.future.apply(@, args).wait()

proxyAll = (src, target, proxyFn) ->
  for key in Object.keys(src) # Gives back the keys on this object, not on prototypes
    do (key) ->
      return if Object::[key]? # Ignore any rewrites of toString, etc which can cause problems
      return if Object.getOwnPropertyDescriptor(src, key).get? # getter methods can have unintentional side effects when called in the wrong context
      return unless typeof src[key] is 'function' # getter methods may throw an exception in some contexts

      target[key] = proxyFn(key)

  target

proxyBuilder = (futureOrSync) ->
  (that) ->
    result =
      if typeof(that) is 'function'

        ize = futureOrSync is 'future' and futureize or synchronize
        func = ize that
        proto = Object.getPrototypeOf(that)[futureOrSync] if Object.getPrototypeOf(that) isnt Function.prototype
        func.__proto__ = proto

        # Transforms an async function that passes multiple arguments
        # to its callback (in addition to err) into one that passes a
        # single argument that is an Array of the non-err args that
        # would be passed to the original callback
        #
        # Ex. The request module passes back the response and the body
        #   request url, (err, response, body) ->
        #     ...
        #
        # This transforms that into something like
        #
        #   requestArray url, (err, response_body) ->
        #     [response, body] = response_body
        #     ...
        #
        # This is useful in Fibrous since synchronized and futureized
        # functions will only return one value, even if the original
        # function passes multiple values to its callback
        #
        # We add .Array to .sync and .future here so that this works:
        #     [response, body] = request.sync.Array url
        #
        thatArrayReturn = ((f, this_) ->
            (args..., callback) ->
              args.push (err, cbArgs...) ->
                callback err, cbArgs
              f.apply this_, args) that, that

        func.Array = ize thatArrayReturn
        func.Array.__proto__ = proto

        func

      else
        Object.create(Object.getPrototypeOf(that) and Object.getPrototypeOf(that)[futureOrSync] or Object::)

    result.that = that

    proxyAll that, result, (key) ->
      (args...) ->
          # Relookup the method every time to pick up reassignments of key on obj or an instance
          @that[key][futureOrSync].apply(@that, args)


defineMemoizedPerInstanceProperty = (target, propertyName, factory) ->
  cacheKey = "__fibrous#{propertyName}__"
  Object.defineProperty target, propertyName,
    enumerable: false
    set: (value) ->
      delete @[cacheKey]
      Object.defineProperty @, propertyName, value: value, writable:true, configurable: true, enumerable: true # allow overriding the property turning back to default behavior
    get: ->
      unless Object::hasOwnProperty.call(@, cacheKey) and @[cacheKey]
        Object.defineProperty @, cacheKey, value: factory(@), writable: true, configurable: true, enumerable: false # ensure the cached version is not enumerable
      @[cacheKey]

# Mixin sync and future to Object and Function
for base in [Object::, Function::]
  defineMemoizedPerInstanceProperty(base, 'future', proxyBuilder('future'))
  defineMemoizedPerInstanceProperty(base, 'sync', proxyBuilder('sync'))

# Wait for all provided futures to resolve:
#
#   result  = fibrous.wait(future)
#   results = fibrous.wait(future1, future2)
#   results = fibrous.wait([future1, future2])
fibrous.wait = (futures...) ->
  getResults = (futureOrArray) ->
    return futureOrArray.get() if (futureOrArray instanceof Future)
    getResults(i) for i in futureOrArray

  Future.wait(futures...)
  result = getResults(futures) # return an array of the results
  result = result[0] if result.length == 1
  result


# Connect middleware ensures that all following request handlers run in a Fiber.
#
# To use with Express:
#
#   var fibrous = require('fibrous');
#   var app = express.createServer();
#   app.use(fibrous.middleware);
#
# Note that non-Fiber cooperative async operations will run outside the fiber.
fibrous.middleware = (req, res, next) ->
  process.nextTick ->
    Fiber ->
      try
        next()
      catch e
        # We expect any errors which bubble up the fiber will be handled by the router
        console.error('Unexpected error bubble up to the top of the fiber:', e?.stack or e)
    .run()

# Create a new fibrous function and run it. Handle errors with try/catch or pass an error
# handler callback as second argument.
#
#  fibrous.run(function() {
#    var data = fs.sync.readFile('/etc/passwd');
#    console.log(data.toString());
#  }, function(err) {
#    console.log("Handle both async and sync errors here", err);
#  });
fibrous.run = (fn, cb) ->
  cb ?= (err) ->
    throw err if err?
  fibrous(fn)(cb)

# Export Future and Fiber for fibrous users
fibrous.Future = Future
fibrous.Fiber = Fiber

packageInfo = require '../package'
fibrous.version = packageInfo.version + "-ccheever"
