require './support/spec_helper'
fibrous = require '../lib/fibrous'
Future = require 'fibers/future'

describe 'fibrous', ->

  asyncObj = null

  describe 'fibrous the function', ->
    beforeEach ->
      asyncObj =
        value: 3

        addValue: (input, cb) ->
          process.nextTick =>
            cb(null, input + @value)

        addValueViaThis: (input, cb) ->
          @addValue input, cb

        fibrousNoAdditionalFutures: fibrous () ->
          1

        fibrousAdd: fibrous (input) ->
          asyncObj.sync.addValue(input)

        fibrousAddViaThis: fibrous (input) ->
          future = new Future()
          @addValue(input, future.resolver())
          future.wait()

        fibrousSyncError: fibrous (input) ->
          throw new Error('immediate error')

        fibrousAsyncError: fibrous (input) ->
          result = asyncObj.sync.addValue(input)
          throw new Error('async error')

        doInFibrous: fibrous (toDoFn) ->
          toDoFn()

    it 'creates an async method which runs in a fiber', (done) ->
      asyncObj.fibrousAdd 10, (err, result) ->
        expect(result).toEqual 13
        done()

    it 'properly handles this', (done) ->
      asyncObj.fibrousAddViaThis 11, (err, result) ->
        expect(result).toEqual 14
        done()

    it 'returns sync errors', (done) ->
      asyncObj.fibrousSyncError 12, (err, result) ->
        expect(err.message).toEqual 'immediate error'
        done()

    it 'returns async errors', (done) ->
      asyncObj.fibrousAsyncError 12, (err, result) ->
        expect(err.message).toEqual 'async error'
        done()

    describe 'from within a fiber', ->

      itFiber 'works in a fiber', ->
        result = asyncObj.sync.fibrousAdd(1)
        expect(result).toEqual 4

      itFiber 'immediate errors work in a fiber', ->
        try
          asyncObj.sync.fibrousSyncError(1)
          jasmine.getEnv().currentSpec.fail('should not get here')
        catch e
          expect(e.message).toEqual 'immediate error'

      itFiber 'async errors work in a fiber', ->
        try
          asyncObj.sync.fibrousAsyncError(1)
          jasmine.getEnv().currentSpec.fail('should not get here')
        catch e
          expect(e.message).toEqual 'async error'

      itFiber 'inherits the fiber if it can to prevent unnecessary fiber spawning', ->
        fiber = Fiber.current
        asyncObj.sync.doInFibrous ->
          expect(Fiber.current).toBe fiber

      itFiber 'avoids creating an unnecessary additional Future', ->
        spyOn(Future.prototype, 'return').andCallThrough()
        result = asyncObj.sync.fibrousNoAdditionalFutures()
        expect(result).toEqual 1
        expect(Future.prototype['return'].callCount).toEqual 1

  describe 'missing or misplaced callbacks seem to work for fibrous methods', ->

    it 'is ok for a fibrous method', (done) ->
      asyncObj.fibrousAdd (err, result) ->
        expect(isNaN result).toBe true
        done()

    itFiber 'is ok for a fibrous method in a fiber', ->
      result = asyncObj.sync.fibrousAdd()
      expect(isNaN result).toBe true

  describe 'wait', ->

    itFiber 'returns an array of all the results of the futures', ->
      future1 = asyncObj.future.addValue(2)
      future2 = asyncObj.future.addValue(3)

      results = fibrous.wait(future1, future2)
      expect(results).toEqual [5,6]

    itFiber 'returns the result for a single argument', ->
      future = asyncObj.future.addValue(2)

      result = fibrous.wait(future)
      expect(result).toEqual 5

    itFiber 'handles arrays of futures', ->
      future1 = asyncObj.future.addValue(2)
      future2 = asyncObj.future.addValue(3)
      future3 = asyncObj.future.addValue(4)

      results = fibrous.wait([future1, future2], future3)
      expect(results).toEqual [[5,6],7]

  describe 'middleware', ->

    it 'runs in a fiber', (done) ->
      expect(Fiber.current).toBeFalsy()
      fibrous.middleware {}, {}, () ->
        expect(Fiber.current).toBeTruthy()
        done()

  describe 'inheritance', ->

    class A
      name: 'instanceA'
      constructor: (name) -> @name = name if name?
      method1: (arg, cb) -> process.nextTick => cb null, "#{@name}.method1(#{arg})"

    A.static1 = (arg, cb) -> process.nextTick => cb null, "#{@name}.static1(#{arg})"

    class B extends A
      name: 'instanceB'
      method2: (arg, cb) -> process.nextTick => cb null, "#{@name}.method2(#{arg})"

    B.static2 = (arg, cb) -> process.nextTick => cb null, "#{@name}.static2(#{arg})"

    a = null
    b = null
    aDog = null
    bCat = null

    beforeEach ->
      a = new A()
      a.method3 = (arg, cb) -> process.nextTick => cb null, "#{@name}.method3(#{arg})"
      b = new B()

      aDog = new A('dog')
      bCat = new B('cat')

    itFiber 'supports static methods', ->
      expect(A.future.static1(5).wait()).toEqual 'A.static1(5)'
      expect(B.future.static2(10).wait()).toEqual 'B.static2(10)'

      expect(A.sync.static1(5)).toEqual 'A.static1(5)'
      expect(B.sync.static2(10)).toEqual 'B.static2(10)'

    itFiber 'only uses a prototype chain, containing only its own methods', ->
      expect(Object.keys(a.future)).toEqual ['that',  'method3']

      expect(Object.keys(a.sync)).toEqual ['that',  'method3']

    it 'caches the results', ->
      expect(b.future).toBe b.future
      expect(b.sync).toBe b.sync
      expect(Object.getPrototypeOf(b.future)).toBe B.prototype.future

    itFiber 'does not add enumerable properties to the instance', ->
      #invoke the getters to ensure the properties are created
      expect(a.future).not.toBeNull()
      expect(a.sync).not.toBeNull()
      expect(a.__fibrousfuture__).not.toBeNull()
      expect(a.__fibroussync__).not.toBeNull()

      # enumerable properties defined on a
      expect(Object.keys(a)).toEqual ['method3']
      # all enumerable properties
      keys = (key for key of a)
      expect(keys).toEqual ['method3', 'name', 'method1']

      expect(b.future).not.toBeNull()
      expect(b.sync).not.toBeNull()
      expect(b.__fibrousfuture__).not.toBeNull()
      expect(b.__fibroussync__).not.toBeNull()

      # enumerable properties defined on a
      expect(Object.keys(b)).toEqual []
      # all enumerable properties
      keys = (key for key of b)
      expect(keys).toEqual ['constructor', 'name', 'method2', 'method1']

    it 'can handle getters which throw exceptions (eg on prototypes)', ->
      # mongoose defines some getters in this way
      obj = {}
      obj.__defineGetter__ 'something', ->
        throw new Error('this getter does not work in this context')


      expect(obj.future).not.toBeNull()
      # we should not get an error

    itFiber 'does not add enumerable properties to the Object and Function prototype', ->
      expect(Object.keys(Object::)).toEqual []
      expect(Object.keys(Function::)).toEqual []

    #TODO: call static1 with no args - what happens....
  
    itFiber 'supports instance methods', ->
      expect(a.future.method3(11).wait()).toEqual 'instanceA.method3(11)'
      expect(a.future.method1(6).wait()).toEqual 'instanceA.method1(6)'
      expect(aDog.future.method1(7).wait()).toEqual 'dog.method1(7)'

      expect(a.sync.method3(11)).toEqual 'instanceA.method3(11)'
      expect(a.sync.method1(6)).toEqual 'instanceA.method1(6)'
      expect(aDog.sync.method1(7)).toEqual 'dog.method1(7)'

    itFiber 'supports inheritance', ->
      expect(b.future.method1(4).wait()).toEqual 'instanceB.method1(4)'
      expect(b.future.method2(6).wait()).toEqual 'instanceB.method2(6)'
      expect(bCat.future.method1(3).wait()).toEqual 'cat.method1(3)'
      expect(bCat.future.method2(5).wait()).toEqual 'cat.method2(5)'

      expect(b.sync.method1(4)).toEqual 'instanceB.method1(4)'
      expect(b.sync.method2(6)).toEqual 'instanceB.method2(6)'
      expect(bCat.sync.method1(3)).toEqual 'cat.method1(3)'
      expect(bCat.sync.method2(5)).toEqual 'cat.method2(5)'

    describe 'sync', ->
      it 'contains methods which only work within a fiber', ->
        try
          b.sync.method1(4)
          jasmine.getEnv().currentSpec.fail('expected the sync version of the method to throw')
        catch e
          expect(e.message).toEqual "Can't wait without a fiber"

    describe 'functions', ->
      f = null

      beforeEach ->
        f = (cb) ->
          process.nextTick =>
            cb(null, "#{@}.f()")

      itFiber 'supports them', ->
        expect(f.future().wait()).toEqual '[object global].f()'
        expect(f.future.call(10).wait()).toEqual '10.f()'

        expect(f.sync()).toEqual '[object global].f()'
        expect(f.sync.call(11)).toEqual '11.f()'

      itFiber 'allows functions to be used as prototypes(not a common use case)', ->
        f.staticF = (cb) ->
          process.nextTick =>
            cb(null, "#{@}.staticF()")
        f.toString = -> 'f'

        obj = Object.create(f)
        obj.toString = -> 'obj'

        expect(f.future.staticF().wait()).toEqual 'f.staticF()'
        expect(obj.future.staticF().wait()).toEqual 'obj.staticF()'

        expect(f.sync.staticF()).toEqual 'f.staticF()'
        expect(obj.sync.staticF()).toEqual 'obj.staticF()'

      itFiber 'avoids creating an unnecessary additional Future when operating on a fibrous function', ->
        f = fibrous -> 'result'

        spyOn(Future.prototype, 'return').andCallThrough()
        expect(f.future().wait()).toEqual 'result'

        expect(Future.prototype['return'].callCount).toEqual 1
