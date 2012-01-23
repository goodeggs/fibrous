require './support/spec_helper'
fibrous = require '../lib/fibrous'

describe 'fibrous', ->

  describe 'wrap async obj', ->

    originalAsyncObj = null
    asyncObj = null


    beforeEach ->
      originalAsyncObj =
        value: 3

        asyncAddValue: (input, cb) ->
          process.nextTick =>
            cb(null, input + @value)
      
        asyncWithThis: (input, cb) ->
          @asyncAddValue input, (err, result) ->
            cb(null, result + 1)
            
      asyncObj = fibrous.wrap(originalAsyncObj)

    describe 'wrap', ->
      it "wraps objects in place", ->
        expect(asyncObj).toBe originalAsyncObj

      it "doesn't rewrap objects", ->
        anotherWrap = fibrous.wrap(originalAsyncObj)
        expect(anotherWrap.future).toBe asyncObj.future

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
        fs = fibrous.require('fs')
        contents = fs.sync.readFile('spec/fixtures/testfile.txt', 'UTF8')
        expect(contents).toEqual 'something exciting\n'

    describe 'future', ->

      it 'returns a future', (done) ->
        future = asyncObj.future.asyncAddValue(2)
        future.resolve (err, result) ->
          expect(result).toEqual 5
          done()

      itFiber 'keeps this as the original object', ->
        originalAsyncObj.value = 5
        result = asyncObj.future.asyncAddValue(2).wait()
        expect(result).toEqual 7

      itFiber 'keeps this as the original object for methods', ->
        result = asyncObj.future.asyncWithThis(2).wait()
        expect(result).toEqual 6

      itFiber 'picks up redefinitions of methods', ->
        originalAsyncObj.asyncAddValue = (input, cb) ->
          process.nextTick ->
            cb(null, -1)

        result = asyncObj.future.asyncAddValue(5).wait()
        expect(result).toEqual(-1)

    describe 'sync', ->

      itFiber 'gives sync version of async methods', ->
        result = asyncObj.sync.asyncAddValue(2)
        expect(result).toEqual 5

      it 'contains methods which only work within a fiber', ->
        try
          asyncObj.sync.asyncAddValue(2)
          jasmine.getEnv().currentSpec.fail('expected the sync version of the method to throw')
        catch e
          expect(e.message).toEqual "Can't wait without a fiber"

