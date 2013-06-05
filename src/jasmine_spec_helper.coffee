fibrous = require('./fibrous')

class jasmine.AsyncBlock extends jasmine.Block
  execute: (onComplete) ->
    completed = false
    complete = (err) =>
      if completed
        console.error "A completed async spec \"#{@spec.getFullName()}\" has completed again with", err?.stack or err
      else
        completed = true
        clearTimeout(timeout)
        @spec.fail(err) if err?
        process.nextTick onComplete # next tick it to prevent the next block from running in the previous block's fiber

    timeout = setTimeout =>
      complete(new Error("spec timed out after #{jasmine.DEFAULT_TIMEOUT_INTERVAL} msec"))
    , jasmine.DEFAULT_TIMEOUT_INTERVAL

    @func.call @spec, complete

for jasmineFunction in [ "it", "beforeEach", "afterEach"]
  do (jasmineFunction) ->
    original = jasmine.Env.prototype[jasmineFunction]
    jasmine.Env.prototype[jasmineFunction] = (args...) ->
      (func = args.pop()) until typeof func is 'function'

      return original.call @, args..., ->
        #Causes non async specs to run inside a fiber
        asyncFunc = (func.length is 1) and func or fibrous(func)
        asyncBlock = new jasmine.AsyncBlock(@env, asyncFunc, @)
        @addToQueue(asyncBlock)
