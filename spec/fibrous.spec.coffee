require './support/spec_helper'
fibrous = require '../lib/fibrous'
Fiber = require 'fibers'
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

    describe 'creates an async method', ->
      it 'which has length > 0', ->
        expect(asyncObj.fibrousAdd.length).toBeGreaterThan 0

      it 'which runs in a fiber', (done) ->
        testRunnerFiber = Fiber.current
        asyncObj.fibrousAdd 10, (err, result) ->
          expect(result).toEqual 13
          expect(Fiber.current).toBeTruthy()
          expect(Fiber.current).not.toBe testRunnerFiber
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

    it 'stores non enumerable references to other versions of the function', ->
      expect('__fibrousFn__' not in Object.keys(asyncObj.fibrousAdd)).toBeTruthy()
      expect('__fibrousFutureFn__' not in Object.keys(asyncObj.fibrousAdd)).toBeTruthy()

    it 'includes the wrapped function body in toString', ->
      expect(asyncObj.fibrousAdd.toString()).toContain 'asyncObj.sync.addValue'

    describe 'from within a fiber', ->

      it 'works in a fiber', ->
        result = asyncObj.sync.fibrousAdd(1)
        expect(result).toEqual 4

      it 'immediate errors work in a fiber', ->
        expect( ->
          asyncObj.sync.fibrousSyncError(1)
        ).toThrow(new Error('immediate error'))

      it 'async errors work in a fiber', ->
        expect(->
          asyncObj.sync.fibrousAsyncError(1)
        ).toThrow(new Error('async error'))

      it 'inherits the fiber if it can to prevent unnecessary fiber spawning', ->
        fiber = Fiber.current
        asyncObj.sync.doInFibrous ->
          expect(Fiber.current).toBe fiber

      it 'only creates one future for the future version', ->
        spyOn(Future.prototype, 'return').andCallThrough()
        result = asyncObj.future.fibrousNoAdditionalFutures().wait()
        expect(result).toEqual 1
        expect(Future.prototype['return'].callCount).toEqual 1

      it 'does not create any futures for the sync version', ->
        spyOn(Future.prototype, 'return').andCallThrough()
        result = asyncObj.sync.fibrousNoAdditionalFutures()
        expect(result).toEqual 1
        expect(Future.prototype['return'].callCount).toEqual 0

  describe 'missing or misplaced callbacks seem to work for fibrous methods', ->

    it 'is ok for a fibrous method', (done) ->
      asyncObj.fibrousAdd (err, result) ->
        expect(isNaN result).toBe true
        done()

    it 'is ok for a fibrous method in a fiber', ->
      result = asyncObj.sync.fibrousAdd()
      expect(isNaN result).toBe true

  describe 'wait', ->

    it 'returns an array of all the results of the futures', ->
      future1 = asyncObj.future.addValue(2)
      future2 = asyncObj.future.addValue(3)

      results = fibrous.wait(future1, future2)
      expect(results).toEqual [5,6]

    it 'returns the result for a single argument', ->
      future = asyncObj.future.addValue(2)

      result = fibrous.wait(future)
      expect(result).toEqual 5

    it 'handles arrays of futures', ->
      future1 = asyncObj.future.addValue(2)
      future2 = asyncObj.future.addValue(3)
      future3 = asyncObj.future.addValue(4)

      results = fibrous.wait([future1, future2], future3)
      expect(results).toEqual [[5,6],7]

  describe 'run', ->
    it 'runs a function in a fiber', (done) ->
      fibrous.run ->
        result = asyncObj.sync.fibrousAdd(1)
        expect(result).toEqual 4
        done()

    it 'passes function return value to the callback', (done) ->
       fibrous.run ->
         asyncObj.sync.fibrousAdd(1)
       , (err, result) ->
         expect(result).toEqual 4
         done()

    it 'passes sync errors to the callback', (done) ->
      fibrous.run ->
        asyncObj.sync.fibrousSyncError(1)
      , (err) ->
        expect(err).toEqual(new Error('immediate error'))
        done()

    it 'passes async errors to the callback', (done) ->
      fibrous.run ->
        asyncObj.sync.fibrousAsyncError(1)
      , (err) ->
        expect(err).toEqual(new Error('async error'))
        done()

  describe 'middleware', ->

    it 'runs in a fiber', (done) ->
      expect(Fiber.current).toBeFalsy()
      fibrous.middleware {}, {}, () ->
        expect(Fiber.current).toBeTruthy()
        done()

  describe 'Future', ->
    it "exports node-fibers Future", ->
      expect(fibrous.Future).toEqual Future

  describe 'an object with overwritten hasOwnProperty', ->
    {obj} = {}

    beforeEach ->
      obj = hasOwnProperty: 'replacing ur functionz, brakin ur expectationz'

    it "does not crash when trying to access sync or future", ->
      expect( -> obj.sync ).not.toThrow()

  describe 'inheritance', ->

    class A
      name: 'instanceA'
      constructor: (name) -> @name = name if name?
      method1: (arg, cb) -> process.nextTick => cb null, "#{@name}.method1(#{arg})"
      @static1 = (arg, cb) -> process.nextTick => cb null, "#{@name}.static1(#{arg})"

    class B extends A
      name: 'instanceB'
      method2: (arg, cb) -> process.nextTick => cb null, "#{@name}.method2(#{arg})"
      @static2 = (arg, cb) -> process.nextTick => cb null, "#{@name}.static2(#{arg})"

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

    it 'supports static methods', ->
      expect(A.future.static1(5).wait()).toEqual 'A.static1(5)'
      expect(B.future.static2(10).wait()).toEqual 'B.static2(10)'

      expect(A.sync.static1(5)).toEqual 'A.static1(5)'
      expect(B.sync.static2(10)).toEqual 'B.static2(10)'

    it 'only uses a prototype chain, containing only its own methods', ->
      expect(Object.keys(a.future)).toEqual ['that',  'method3']
      expect(Object.keys(a.sync)).toEqual ['that',  'method3']

    it 'properly sets up the prototype chain of the proxies to derive from Object.prototype', ->
      # There was a bug with a null root of the prototype chain which was causing weird exception stack traces
      expect(a.sync.__lookupGetter__).toBeTruthy()
      expect(a.future.__lookupGetter__).toBeTruthy()
      expect(A.sync.__lookupGetter__).toBeTruthy()
      expect(A.future.__lookupGetter__).toBeTruthy()

    it 'caches the results', ->
      expect(b.future).toBe b.future
      expect(b.sync).toBe b.sync
      expect(Object.getPrototypeOf(b.future)).toBe B.prototype.future

    it 'does not add enumerable properties to the instance', ->
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

    it 'allows overriding the sync or future properties', ->
      # for instance, some external packages define sync or future methods in this way
      f = ->
      s = ->

      expect(a.future).toBeTruthy()
      expect(a.future).not.toEqual f
      expect('future' in Object.keys(a)).not.toBeTruthy()
      expect(a.hasOwnProperty('__fibrousfuture__')).toBeTruthy()

      expect(a.sync).toBeTruthy()
      expect(a.sync).not.toEqual s
      expect('sync' in Object.keys(a)).not.toBeTruthy()
      expect(a.hasOwnProperty('__fibroussync__')).toBeTruthy()

      a.future = f
      expect(a.future).toEqual f
      expect('future' in Object.keys(a)).toBeTruthy() # now enumerable
      expect(a.hasOwnProperty('__fibrousfuture__')).not.toBeTruthy()

      a.sync = s
      expect(a.sync).toEqual s
      expect('sync' in Object.keys(a)).toBeTruthy() # now enumerable
      expect(a.hasOwnProperty('__fibroussync__')).not.toBeTruthy()

    it 'ignores getter functions', ->
      # mongoose defines some getters in this way; and calling the getter in the wrong context (eg. on a prototype)
      # can have bad side effects
      obj = {}
      Object.defineProperty obj, 'someGetter',
          get: ->
            (cb) -> cb(null, 'some result')
          enumerable: true

      expect('someGetter' in Object.keys(obj)).toBeTruthy()
      expect(typeof obj.someGetter).toEqual 'function'
      expect(obj.future.someGetter).not.toBeDefined()

      # mongoose defines some getters which throw exceptions when called with the wrong context
      Object.defineProperty obj, 'exception',
          get: -> throw new Error('this getter does not work in this context')
          enumerable: true

      expect('exception' in Object.keys(obj)).toBeTruthy()
      # we should not get an error
      expect(obj.future.exception).not.toBeDefined()

    it 'does not add enumerable properties to the Object and Function prototype', ->
      expect(Object.keys(Object::)).toEqual []
      expect(Object.keys(Function::)).toEqual []

    it 'supports instance methods', ->
      expect(a.future.method3(11).wait()).toEqual 'instanceA.method3(11)'
      expect(a.future.method1(6).wait()).toEqual 'instanceA.method1(6)'
      expect(aDog.future.method1(7).wait()).toEqual 'dog.method1(7)'

      expect(a.sync.method3(11)).toEqual 'instanceA.method3(11)'
      expect(a.sync.method1(6)).toEqual 'instanceA.method1(6)'
      expect(aDog.sync.method1(7)).toEqual 'dog.method1(7)'

    it 'supports inheritance', ->
      expect(b.future.method1(4).wait()).toEqual 'instanceB.method1(4)'
      expect(b.future.method2(6).wait()).toEqual 'instanceB.method2(6)'
      expect(bCat.future.method1(3).wait()).toEqual 'cat.method1(3)'
      expect(bCat.future.method2(5).wait()).toEqual 'cat.method2(5)'

      expect(b.sync.method1(4)).toEqual 'instanceB.method1(4)'
      expect(b.sync.method2(6)).toEqual 'instanceB.method2(6)'
      expect(bCat.sync.method1(3)).toEqual 'cat.method1(3)'
      expect(bCat.sync.method2(5)).toEqual 'cat.method2(5)'

    it 'does not copy over overwritten Object.prototype methods (like toString) which can break some behaviors (eg. toStringing the sync Object)', ->
      b.toString = -> 'alternate toString'
      expect('toString' not in Object.keys(b.future)).toBeTruthy()
      expect('toLocaleString' not in Object.keys(b.future)).toBeTruthy()
      expect('toString' not in Object.keys(b.sync)).toBeTruthy()
      expect('toLocaleString' not in Object.keys(b.sync)).toBeTruthy()

    describe 'future', ->
      it 'return synchronous errors via the future', ->
        f = (cb) -> throw new Error('BOOM')
        future = f.future()

        expect(->
          future.wait()
        ).toThrow(new Error('BOOM'))

    describe 'sync', ->
      it 'contains methods which only work within a fiber', (done) ->
        expect(->
          b.sync.method1(4)
        ).toThrow(new Error "Can't wait without a fiber")
        done()

    describe 'functions', ->
      f = null

      beforeEach ->
        f = (cb) ->
          process.nextTick =>
            cb(null, "#{@}.f()")

      it 'supports them', ->
        expect(f.future().wait()).toEqual '[object global].f()'
        expect(f.future.call(10).wait()).toEqual '10.f()'

        expect(f.sync()).toEqual '[object global].f()'
        expect(f.sync.call(11)).toEqual '11.f()'

      it 'allows functions to be used as prototypes', ->
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

      it 'allows functions to be used as prototypes of other functions', ->
        f.staticF = (cb) ->
          process.nextTick =>
            cb(null, "#{@}.staticF()")
        f.toString = ->
          'f'

        otherF = ->
        otherF.__proto__ = f
        otherF.toString = ->
          'otherF'

        expect(f.future.staticF().wait()).toEqual 'f.staticF()'
        expect(otherF.future.staticF().wait()).toEqual 'otherF.staticF()'

        expect(f.sync.staticF()).toEqual 'f.staticF()'
        expect(otherF.sync.staticF()).toEqual 'otherF.staticF()'

      it 'avoids creating an unnecessary additional Future when operating on a fibrous function', ->
        f = fibrous -> 'result'

        spyOn(Future.prototype, 'return').andCallThrough()
        expect(f.future().wait()).toEqual 'result'

        expect(Future.prototype['return'].callCount).toEqual 1
