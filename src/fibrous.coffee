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
  eval """
    var asyncFn = function(#{('a' for [1..fn.length+1]).join(',')}) {
      var args = Array.prototype.slice.call(arguments, 0);
      var callback = args.pop();
      if (!(callback instanceof Function))
        throw new Error('Fibrous method expects a callback');
      var future = futureFn.apply(this, args);
      future.resolve(callback);
    };
  """
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

skipProps = {
  constructor: true
  sync: true
  future: true
}

proxyAll = (src, target, proxyFn) ->
  for key in Object.getOwnPropertyNames(src) # Gives back the keys (including non-enumerable) on this object, not on prototypes
    do (key) ->
      return if skipProps[key]
      return if Object::[key]? # Ignore any rewrites of toString, etc which can cause problems
      propertyDescriptor = Object.getOwnPropertyDescriptor(src, key)
      return if propertyDescriptor.get? # getter methods can have unintentional side effects when called in the wrong context
      return unless typeof src[key] is 'function' # getter methods may throw an exception in some contexts

      Object.defineProperty(target, key, {
        configurable: propertyDescriptor.configurable
        enumerable: propertyDescriptor.enumerable
        writable: propertyDescriptor.writable
        value: proxyFn(key)
      })

  target

proxyBuilder = (futureOrSync) ->
  (that) ->
    result =
      if typeof(that) is 'function'
        func = (futureOrSync is 'future' and futureize or synchronize)(that)
        func.__proto__ = Object.getPrototypeOf(that)[futureOrSync] if Object.getPrototypeOf(that) isnt Function.prototype
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

# Export Future for fibrous users
fibrous.Future = Future
