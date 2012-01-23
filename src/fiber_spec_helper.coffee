require 'fibers'

module.exports = fiber_spec_helper = {}

# Add 'itFiber', 'beforeEachFiber', 'afterEachFiber' to wrap each spec or callback in a Fiber
for jasmineFunction in [ "it", "beforeEach", "afterEach"]
  do (jasmineFunction) ->
    original = global[jasmineFunction]
    global[jasmineFunction + 'Fiber'] = (args...) ->
      spec = args.pop()
      original args..., =>
        done = false
        runs ->
          future = spec.future().apply(@)
          future.resolve (err, result) ->
            done = true
            jasmine.getEnv().currentSpec.fail(err) if err?
        waitsFor ->
          done == true
        , "fiber to complete"
