fibrous = require('./fibrous')

module.exports = fiber_spec_helper =
  addFiberVariants: () ->
    originalRunner = jasmine.Runner.prototype.execute
    jasmine.Runner.prototype.execute = (args...) ->
      fibrous(originalRunner.bind(@, args...)) (err, result) ->
        throw err if err?

    # This is a bummer hack, and breaks the setTimeout semantics to sleep the Runner fiber (thus, the fiber does not
    # continue during the duration); but is necessary because jasmine calls an occasional timeout to prevent event
    # loop starvation - see jasmine.DEFAULT_UPDATE_INTERVAL.
    # TODO(randy): try a different fiber per spec
    jasmine.Env.prototype.setTimeout = (f, time) ->
      asyncF = (cb) ->
        global.setTimeout cb, time

      asyncF.sync()
      f()

    for jasmineFunction in [ "it", "beforeEach", "afterEach"]
      do (jasmineFunction) ->
        original = jasmine.Env.prototype[jasmineFunction]
        jasmine.Env.prototype[jasmineFunction] = (args...) ->
          spec = args.pop()

          # non async specs
          return original.call @, args..., spec if spec.length is 0

          # Async specs with a done callback
          original.call @, args..., ->
            duration = 5000
            asyncSpecFuture = spec.future()

            timeout = setTimeout =>
              msg = "spec timed out after #{duration} msec waiting for the asynchronous done callback to be called"
              asyncSpecFuture.throw(new Error(msg)) unless asyncSpecFuture.isResolved()
            , duration

            # For async specs, pause the runner fiber until the spec completes
            asyncSpecFuture.wait()
            clearTimeout(timeout)
