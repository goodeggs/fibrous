require './support/spec_helper'
fibrous = require '../lib/fibrous'
Future = require 'fibers/future'

fs = fibrous.require('fs')


describe 'fibrous', ->

  asyncObj = null

  beforeEach ->
    asyncObj = fibrous.wrap
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

  describe 'wrap', ->
    it "wraps objects in place", ->
      obj = {fn: ->}
      originalObj = obj
      returned = fibrous.wrap(obj)

      expect(obj).toBe originalObj
      expect(returned).toBe originalObj

    it "doesn't rewrap objects", ->
      originalFuture = asyncObj.future
      fibrous.wrap(asyncObj)
      expect(asyncObj.future).toBe originalFuture

    it 'will not wrap objects which already have sync attributes', ->
      obj = {sync: ->}
      try
        fibrous.wrap(obj)
        jasmine.getEnv().currentSpec.fail('should not have gotten here')
      catch e
        expect(e.message).toEqual 'the object to wrap already has a .sync attribute [function () {}]'

    it 'will not wrap objects which already have future attributes', ->
      obj = {future: 2020}
      try
        fibrous.wrap(obj)
        jasmine.getEnv().currentSpec.fail('should not have gotten here')
      catch e
        expect(e.message).toEqual 'the object to wrap already has a .future attribute [2020]'

  describe 'require', ->
    itFiber 'works with built in modules', ->
      contents = fs.sync.readFile('spec/fixtures/testfile.txt', 'UTF8')
      expect(contents).toEqual 'something exciting\n'

  describe 'fibrous', ->
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

  describe 'future', ->

    it 'returns a future', (done) ->
      future = asyncObj.future.addValue(2)
      future.resolve (err, result) ->
        expect(result).toEqual 5
        done()

    itFiber 'keeps this as the original object', ->
      asyncObj.value = 5
      result = asyncObj.future.addValue(2).wait()
      expect(result).toEqual 7

    itFiber 'keeps this as the original object for methods', ->
      result = asyncObj.future.addValueViaThis(2).wait()
      expect(result).toEqual 5

    itFiber 'picks up redefinitions of methods', ->
      asyncObj.addValue = (input, cb) ->
        process.nextTick ->
          cb(null, -1)

      result = asyncObj.future.addValue(5).wait()
      expect(result).toEqual(-1)

  describe 'sync', ->

    itFiber 'gives sync version of async methods', ->
      result = asyncObj.sync.addValue(2)
      expect(result).toEqual 5

    it 'contains methods which only work within a fiber', ->
      try
        asyncObj.sync.addValue(2)
        jasmine.getEnv().currentSpec.fail('expected the sync version of the method to throw')
      catch e
        expect(e.message).toEqual "Can't wait without a fiber"

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
